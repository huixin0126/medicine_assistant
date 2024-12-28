from flask import Flask, request, jsonify
import cv2
import pytesseract
from pytesseract import Output
import os
from collections import Counter
import numpy as np

pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'
app = Flask(__name__)

def enhance_contrast(image):
    # Convert to LAB color space
    lab = cv2.cvtColor(image, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    
    # Apply CLAHE to L channel for better contrast
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8,8))
    cl = clahe.apply(l)
    
    # Optional: Histogram equalization to further enhance contrast
    cl = cv2.equalizeHist(cl)
    
    # Merge channels
    enhanced = cv2.merge((cl,a,b))
    return cv2.cvtColor(enhanced, cv2.COLOR_LAB2BGR)

def color_threshold(image):
    # Convert to HSV color space
    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
    
    # Define range for brown/chocolate color
    lower_brown = np.array([10, 50, 50])
    upper_brown = np.array([30, 255, 255])
    
    # Create mask for brown color
    mask = cv2.inRange(hsv, lower_brown, upper_brown)
    return mask

def deskew_image(image):
    # Convert to grayscale
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    
    # Apply binary thresholding
    _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    
    # Find contours in the binary image
    contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    # Get the bounding box for the largest contour
    largest_contour = max(contours, key=cv2.contourArea)
    rect = cv2.minAreaRect(largest_contour)
    angle = rect[-1]
    
    # Correct the angle based on its sign (OpenCV returns angles between -90 to 0 and 0 to 90 degrees)
    if angle < -45:
        angle = -(90 + angle)  # Counter-clockwise rotation
    else:
        angle = -angle  # Clockwise rotation
    
    # Get the rotation matrix
    height, width = image.shape[:2]
    rotation_matrix = cv2.getRotationMatrix2D((width / 2, height / 2), angle, 1)
    
    # Rotate the image to deskew it
    rotated_image = cv2.warpAffine(image, rotation_matrix, (width, height), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
    
    return rotated_image

# def preprocess_image(image):
#     # Deskew the image to correct any tilt
#     image = deskew_image(image)

#     # Enhance contrast
#     enhanced = enhance_contrast(image)

#     # Apply bilateral filter to reduce noise while preserving edges
#     filtered = cv2.bilateralFilter(enhanced, 9, 75, 75)
    
#     # Convert to grayscale for edge detection
#     gray = cv2.cvtColor(filtered, cv2.COLOR_BGR2GRAY)
    
#     # Use adaptive thresholding with Otsu's method for better results
#     _, otsu_binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    
#     # Noise removal with morphological operations
#     kernel = np.ones((2,2), np.uint8)
#     cleaned = cv2.morphologyEx(otsu_binary, cv2.MORPH_CLOSE, kernel)
    
#     # Additional denoising
#     cleaned = cv2.fastNlMeansDenoising(cleaned, None, 10, 7, 21)
    
#     return cleaned

def preprocess_image(image):
    # Step 1: Deskew the image
    image = deskew_image(image)
    
    # Step 2: Enhance contrast using LAB color space
    enhanced = enhance_contrast(image)
    
    # Step 3: Apply sharpening filter
    kernel = np.array([[0, -1, 0], [-1, 5, -1], [0, -1, 0]])
    sharpened = cv2.filter2D(enhanced, -1, kernel)
    
    # Step 4: Convert to grayscale for further processing
    gray = cv2.cvtColor(sharpened, cv2.COLOR_BGR2GRAY)
    
    # Step 5: Adaptive Thresholding for better binarization
    adaptive_thresh = cv2.adaptiveThreshold(
        gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2)
    
    # Step 6: Morphological operations to remove small noise
    kernel = np.ones((2, 2), np.uint8)
    morphed = cv2.morphologyEx(adaptive_thresh, cv2.MORPH_CLOSE, kernel)
    
    return morphed


def segment_text_regions(image):
    # Step 1: Convert to grayscale
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    
    # Step 2: Threshold the image
    _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    
    # Step 3: Find contours in the binary image
    contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    # Step 4: Extract bounding boxes
    regions = []
    for contour in contours:
        x, y, w, h = cv2.boundingRect(contour)
        if w > 50 and h > 15:  # Ignore very small regions
            regions.append(image[y:y+h, x:x+w])
    
    return regions

def find_prominent_text(data, image_height):
    words = []
    heights = []
    confidences = []
    
    n_boxes = len(data['text'])
    for i in range(n_boxes):
        text = data['text'][i].strip()
        if len(text) < 3:  # Skip very short text
            continue
            
        conf = float(data['conf'][i])
        if conf < 30:  # Skip low confidence detections
            continue
            
        # Calculate relative height
        height = data['height'][i] / image_height * 100
        
        words.append(text.upper())  # Convert to uppercase for better matching
        heights.append(height)
        confidences.append(conf)
    
    return words, heights, confidences

# def detect_medicine_name(image_path):
#     # Read and preprocess image
#     image = cv2.imread(image_path)
#     processed_image = preprocess_image(image)
    
#     # Get OCR data with optimized configuration for metallic backgrounds
#     custom_config = r'--oem 3 --psm 6'  # Mode 6 is good for sparse text
#     data = pytesseract.image_to_data(processed_image, config=custom_config, output_type=Output.DICT)
    
#     # Find prominent text
#     words, heights, confidences = find_prominent_text(data, image.shape[0])
    
#     # Strategy 1: Find most frequent word (for repeated text like "ROYCE")
#     word_counter = Counter(words)
#     frequent_words = word_counter.most_common(3)  # Get top 3 most frequent words
    
#     # Strategy 2: Find largest text (for brand names like "WONDERPLAN")
#     max_height_idx = heights.index(max(heights)) if heights else -1
#     largest_text = words[max_height_idx] if max_height_idx != -1 else ""
    
#     # Decision making logic
#     medicine_name = ""
    
#     # If we have a very frequent word (appears more than twice)
#     if frequent_words and frequent_words[0][1] > 2:
#         medicine_name = frequent_words[0][0]
    
#     # If we have a very large text and it's not a common word/number
#     elif largest_text and len(largest_text) > 3 and not largest_text.isdigit():
#         medicine_name = largest_text
    
#     # Fallback to most confident text if other methods fail
#     elif words:
#         max_conf_idx = confidences.index(max(confidences))
#         medicine_name = words[max_conf_idx]
    
#     # Clean up the detected name
#     medicine_name = medicine_name.strip()
#     medicine_name = ''.join(c for c in medicine_name if c.isalnum() or c.isspace())
    
#     return medicine_name

def detect_medicine_name(image_path):
    # Step 1: Read the image
    image = cv2.imread(image_path)
    
    # Step 2: Preprocess the image
    processed_image = preprocess_image(image)
    
    # Step 3: Segment text regions
    regions = segment_text_regions(image)
    
    # Step 4: Perform OCR on the segmented regions
    custom_config = r'--oem 3 --psm 11'
    detected_texts = []
    for region in regions:
        text = pytesseract.image_to_string(region, config=custom_config)
        detected_texts.append(text.strip())
    
    # Step 5: Consolidate detected text
    all_text = " ".join(detected_texts)
    
    # Step 6: Clean up and deduplicate
    words = [word.upper() for word in all_text.split() if len(word) > 2]
    word_counter = Counter(words)
    most_common_word = word_counter.most_common(1)
    
    medicine_name = most_common_word[0][0] if most_common_word else "Unknown"
    return medicine_name

@app.route('/detect-medicine', methods=['POST'])
def detect_medicine():
    if 'file' not in request.files:
        return jsonify({'error': 'No file uploaded'}), 400
        
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400
        
    # Create uploads directory if it doesn't exist
    os.makedirs('uploads', exist_ok=True)
    
    try:
        # Save and process the file
        file_path = os.path.join('uploads', file.filename)
        file.save(file_path)
        
        # Detect medicine name
        medicine_name = detect_medicine_name(file_path)
        
        # Clean up
        os.remove(file_path)
        
        return jsonify({'medicine_name': medicine_name})
        
    except Exception as e:
        if os.path.exists(file_path):
            os.remove(file_path)
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
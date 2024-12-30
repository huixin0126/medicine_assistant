import 'dart:io';
import 'package:flutter/material.dart';
import 'package:medicine_assistant_app/widget/image_viewer.dart';
import 'dart:convert'; // For base64 decoding

Widget chatDialog({
  required String name,
  String? message,
  String? imageUrl, // Optional image URL
  required bool isLeft,
  required BuildContext context,
  String? avatar, // URL or path for the avatar image
  File? image, // Optional image file
}) {
  return Row(
    mainAxisAlignment: isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (isLeft) ...[
        CircleAvatar(
          backgroundImage: (avatar != null && avatar.isNotEmpty)
              ? NetworkImage(avatar)
              : null,
          child: (avatar == null || avatar.isEmpty)
              ? Icon(Icons.account_circle, size: 40)
              : null,
        ),
        const SizedBox(width: 8),
      ],
      Flexible(
        child: Column(
          crossAxisAlignment:
              isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Align(
              alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
              child: Text(
                name.isNotEmpty ? name : 'Unknown User',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.symmetric(vertical: 4),
              constraints: const BoxConstraints(maxWidth: 300),
              decoration: BoxDecoration(
                color: isLeft ? Colors.grey[300] : Colors.blue[100],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: isLeft ? const Radius.circular(0) : const Radius.circular(12),
                  bottomRight: isLeft ? const Radius.circular(12) : const Radius.circular(0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (image != null)
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ImageViewerScreen(imageFile: image),
                          ),
                        );
                      },
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            image,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  if (imageUrl != null && image == null)
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ImageViewerScreen(imageUrl: imageUrl),
                          ),
                        );
                      },
                      child: (imageUrl.startsWith('data:image'))
                          ? Image.memory(
                              base64Decode(imageUrl.split(',').last),
                              width: 200,
                              height: 200,
                              fit: BoxFit.cover,
                            )
                          : Image.network(
                              imageUrl,
                              width: 200,
                              height: 200,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            (loadingProgress.expectedTotalBytes ?? 1)
                                        : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(Icons.broken_image, size: 200);
                              },
                            ),
                    ),
                  if (message != null && message.isNotEmpty) ...[
                    if (image != null || imageUrl != null) const SizedBox(height: 8),
                    Text(
                      message,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      if (!isLeft) ...[
        const SizedBox(width: 8),
        CircleAvatar(
          backgroundImage: (avatar != null && avatar.isNotEmpty)
              ? NetworkImage(avatar)
              : null,
          child: (avatar == null || avatar.isEmpty)
              ? Icon(Icons.account_circle, size: 40)
              : null,
        ),

      ],
    ],
  );
}

class User {
  final String userID;
  final String name;
  final String email;
  final String phoneNo;
  final String? deviceToken;
  final String? emergencyContact;
  final Map<String, dynamic>? faceData;
  final List<String> guardianIDs;
  final List<String> seniorIDs;
  final String? avatar; 

  User({
    required this.userID,
    required this.name,
    required this.email,
    required this.phoneNo,
    this.deviceToken,
    this.emergencyContact,
    this.faceData,
    this.guardianIDs = const [],
    this.seniorIDs = const [],
    this.avatar, 
  });

  Map<String, dynamic> toJson() => {
    'userID': userID,
    'name': name,
    'email': email,
    'phoneNo': phoneNo,
    'deviceToken': deviceToken,
    'emergencyContact': emergencyContact,
    'faceData': faceData,
    'guardianIDs': guardianIDs,
    'seniorIDs': seniorIDs,
    'avatar': avatar, 
  };

  factory User.fromJson(Map<String, dynamic> json) => User(
    userID: json['userID'],
    name: json['name'],
    email: json['email'],
    phoneNo: json['phoneNo'],
    deviceToken: json['deviceToken'],
    emergencyContact: json['emergencyContact'],
    faceData: json['faceData'],
    guardianIDs: List<String>.from(json['guardianIDs'] ?? []),
    seniorIDs: List<String>.from(json['seniorIDs'] ?? []),
    avatar: json['avatar'],  
  );
}

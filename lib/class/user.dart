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
  final String? faceImageUrl;

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
    this.faceImageUrl,
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

  User copyWith({
    String? userID,
    String? name,
    String? email,
    String? phoneNo,
    String? avatar,
    String? emergencyContact,
    List<String>? guardianIDs,
    List<String>? seniorIDs,
  }) {
    return User(
      userID: userID ?? this.userID,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNo: phoneNo ?? this.phoneNo,
      avatar: avatar ?? this.avatar,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      guardianIDs: guardianIDs ?? List<String>.from(this.guardianIDs),
      seniorIDs: seniorIDs ?? List<String>.from(this.seniorIDs),
    );
  }
  
}

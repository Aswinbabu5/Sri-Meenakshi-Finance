class CustomerModel {
  final int id;
  final String cusCode;
  final String name;
  final String? fatherOrSpouseName;
  final String phoneNumber;
  final String? address;
  final String city;
  final String? photoPath; // Customer Face / Profile Photo
  final String? proofType; // Reference type: Aadhaar, PAN, Voter ID, Ration Card, etc.
  final String? proofFrontPath; // Front photo of ID proof
  final String? proofBackPath; // Back photo of ID proof
  final String? notes;
  final String status;
  final bool isTargetCustomer;

  CustomerModel({
    required this.id,
    required this.cusCode,
    required this.name,
    this.fatherOrSpouseName,
    required this.phoneNumber,
    this.address,
    this.city = "Madurai",
    this.photoPath,
    this.proofType,
    this.proofFrontPath,
    this.proofBackPath,
    this.notes,
    this.status = "active",
    this.isTargetCustomer = false,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] ?? 0,
      cusCode: json['cus_Code'] ?? json['cusCode'] ?? json['cus_code'] ?? '',
      name: json['name'] ?? '',
      fatherOrSpouseName: json['fatherOrSpouseName'] ?? json['father_or_spouse_name'],
      phoneNumber: json['phone_Number'] ?? json['phoneNumber'] ?? json['phone_number'] ?? '',
      address: json['address'],
      city: json['city'] ?? 'Madurai',
      photoPath: json['photoPath'] ?? json['photo_path'],
      proofType: json['proofType'] ?? json['proof_type'],
      proofFrontPath: json['proofFrontPath'] ?? json['proof_front_path'],
      proofBackPath: json['proofBackPath'] ?? json['proof_back_path'],
      notes: json['notes'],
      status: json['status'] ?? 'active',
      isTargetCustomer: json['isTargetCustomer'] == true || json['is_target_customer'] == 1 || json['is_target_customer'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cus_Code': cusCode,
      'name': name,
      'fatherOrSpouseName': fatherOrSpouseName,
      'phone_Number': phoneNumber,
      'address': address,
      'city': city,
      'photoPath': photoPath,
      'proofType': proofType,
      'proofFrontPath': proofFrontPath,
      'proofBackPath': proofBackPath,
      'notes': notes,
      'status': status,
      'isTargetCustomer': isTargetCustomer,
    };
  }

  Map<String, dynamic> toDbMap() {
    return {
      if (id > 0) 'id': id,
      'cus_code': cusCode,
      'name': name,
      'father_or_spouse_name': fatherOrSpouseName,
      'phone_number': phoneNumber,
      'address': address,
      'city': city,
      'photo_path': photoPath,
      'proof_type': proofType,
      'proof_front_path': proofFrontPath,
      'proof_back_path': proofBackPath,
      'notes': notes,
      'status': status,
      'is_target_customer': isTargetCustomer ? 1 : 0,
    };
  }

  CustomerModel copyWith({
    int? id,
    String? cusCode,
    String? name,
    String? fatherOrSpouseName,
    String? phoneNumber,
    String? address,
    String? city,
    String? photoPath,
    String? proofType,
    String? proofFrontPath,
    String? proofBackPath,
    String? notes,
    String? status,
    bool? isTargetCustomer,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      cusCode: cusCode ?? this.cusCode,
      name: name ?? this.name,
      fatherOrSpouseName: fatherOrSpouseName ?? this.fatherOrSpouseName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      city: city ?? this.city,
      photoPath: photoPath ?? this.photoPath,
      proofType: proofType ?? this.proofType,
      proofFrontPath: proofFrontPath ?? this.proofFrontPath,
      proofBackPath: proofBackPath ?? this.proofBackPath,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      isTargetCustomer: isTargetCustomer ?? this.isTargetCustomer,
    );
  }
}

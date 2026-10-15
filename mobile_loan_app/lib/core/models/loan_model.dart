import 'customer_model.dart';

class LoanModel {
  final int id;
  final String bondNumber; // e.g. A001 (no hyphen)
  final String lineCode; // e.g. A
  final int customerId;
  final CustomerModel? customer;
  final String customerName;
  final String? fatherOrSpouseName;
  final String phoneNumber;
  final String? address;
  final String? city;
  final String? photoPath; // Customer Face / Profile Photo
  final String? proofType; // Reference type: Aadhaar, PAN, Voter ID, Ration Card, etc.
  final String? proofFrontPath; // Front photo of ID proof
  final String? proofBackPath; // Back photo of ID proof

  final int tenureDays; // 100 days
  final double loanAmount;
  final double interestRate;
  final double interestAmount;
  final double totalAmount;
  final double dailyDueAmount;
  final double chitFee;

  final DateTime startDate;
  final DateTime endDate;
  DateTime? finishedDate; // Date when the loan was fully paid off/settled

  double collectedAmount;
  double balanceAmount;
  String status; // active, closed, overdue
  final bool isTargetCustomer;

  /// Total upfront deductions: interest amount + document charges (chit fee) + days
  double get totalDeductions => interestAmount + chitFee + tenureDays;

  /// Disbursed amount handed to customer: original amount - (interest amnt + document charges + days)
  /// E.g. (10000 - (1000 + 100 + 100)) = 8800
  double get disbursedAmount => loanAmount - totalDeductions;

  LoanModel({
    required this.id,
    required this.bondNumber,
    required this.lineCode,
    required this.customerId,
    this.customer,
    required this.customerName,
    this.fatherOrSpouseName,
    required this.phoneNumber,
    this.address,
    this.city,
    this.photoPath,
    this.proofType,
    this.proofFrontPath,
    this.proofBackPath,
    this.tenureDays = 100,
    required this.loanAmount,
    this.interestRate = 1.0,
    required this.interestAmount,
    required this.totalAmount,
    required this.dailyDueAmount,
    this.chitFee = 100,
    required this.startDate,
    required this.endDate,
    this.finishedDate,
    this.collectedAmount = 0,
    required this.balanceAmount,
    this.status = 'active',
    this.isTargetCustomer = false,
  });

  factory LoanModel.fromJson(Map<String, dynamic> json) {
    CustomerModel? cust;
    if (json['customer'] != null && json['customer'] is Map<String, dynamic>) {
      cust = CustomerModel.fromJson(json['customer']);
    }

    return LoanModel(
      id: json['id'] ?? 0,
      bondNumber: json['bondNumber'] ?? json['bond_number'] ?? '',
      lineCode: json['lineCode'] ?? json['line_code'] ?? 'A',
      customerId: json['customerId'] ?? json['customer_id'] ?? 0,
      customer: cust,
      customerName: cust?.name ?? json['customerName'] ?? json['customer_name'] ?? '',
      fatherOrSpouseName: cust?.fatherOrSpouseName ?? json['fatherOrSpouseName'] ?? json['father_or_spouse_name'],
      phoneNumber: cust?.phoneNumber ?? json['phoneNumber'] ?? json['phone_number'] ?? '',
      address: cust?.address ?? json['address'],
      city: cust?.city ?? json['city'],
      photoPath: cust?.photoPath ?? json['photoPath'] ?? json['photo_path'],
      proofType: cust?.proofType ?? json['proofType'] ?? json['proof_type'],
      proofFrontPath: cust?.proofFrontPath ?? json['proofFrontPath'] ?? json['proof_front_path'],
      proofBackPath: cust?.proofBackPath ?? json['proofBackPath'] ?? json['proof_back_path'],
      tenureDays: json['tenureDays'] ?? json['tenure_days'] ?? 100,
      loanAmount: (json['loanAmount'] ?? json['loan_amount'] as num?)?.toDouble() ?? 0.0,
      interestRate: (json['interestRate'] ?? json['interest_rate'] as num?)?.toDouble() ?? 1.0,
      interestAmount: (json['interestAmount'] ?? json['interest_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['totalAmount'] ?? json['total_amount'] as num?)?.toDouble() ?? 0.0,
      dailyDueAmount: (json['dailyDueAmount'] ?? json['daily_due_amount'] as num?)?.toDouble() ?? 0.0,
      chitFee: (json['chitFee'] ?? json['chit_fee'] as num?)?.toDouble() ?? 100.0,
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate']) ?? DateTime.now()
          : (json['start_date'] != null ? DateTime.tryParse(json['start_date']) ?? DateTime.now() : DateTime.now()),
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate']) ?? DateTime.now().add(const Duration(days: 100))
          : (json['end_date'] != null ? DateTime.tryParse(json['end_date']) ?? DateTime.now().add(const Duration(days: 100)) : DateTime.now().add(const Duration(days: 100))),
      finishedDate: json['finishedDate'] != null
          ? DateTime.tryParse(json['finishedDate'])
          : (json['finished_date'] != null ? DateTime.tryParse(json['finished_date']) : null),
      collectedAmount: (json['collectedAmount'] ?? json['collected_amount'] as num?)?.toDouble() ?? 0.0,
      balanceAmount: (json['balanceAmount'] ?? json['balance_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'active',
      isTargetCustomer: json['isTargetCustomer'] == true || json['is_target_customer'] == 1 || json['is_target_customer'] == true || (cust?.isTargetCustomer ?? false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bondNumber': bondNumber,
      'lineCode': lineCode,
      'customerId': customerId,
      'customerName': customerName,
      'fatherOrSpouseName': fatherOrSpouseName,
      'phoneNumber': phoneNumber,
      'address': address,
      'city': city,
      'photoPath': photoPath,
      'proofType': proofType,
      'proofFrontPath': proofFrontPath,
      'proofBackPath': proofBackPath,
      'tenureDays': tenureDays,
      'loanAmount': loanAmount,
      'interestRate': interestRate,
      'interestAmount': interestAmount,
      'totalAmount': totalAmount,
      'dailyDueAmount': dailyDueAmount,
      'chitFee': chitFee,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'finishedDate': finishedDate?.toIso8601String(),
      'collectedAmount': collectedAmount,
      'balanceAmount': balanceAmount,
      'status': status,
      'isTargetCustomer': isTargetCustomer,
    };
  }

  Map<String, dynamic> toDbMap() {
    return {
      if (id > 0) 'id': id,
      'bond_number': bondNumber,
      'line_code': lineCode,
      'customer_id': customerId,
      'customer_name': customerName,
      'father_or_spouse_name': fatherOrSpouseName,
      'phone_number': phoneNumber,
      'address': address,
      'city': city,
      'photo_path': photoPath,
      'proof_type': proofType,
      'proof_front_path': proofFrontPath,
      'proof_back_path': proofBackPath,
      'tenure_days': tenureDays,
      'loan_amount': loanAmount,
      'interest_rate': interestRate,
      'interest_amount': interestAmount,
      'total_amount': totalAmount,
      'daily_due_amount': dailyDueAmount,
      'chit_fee': chitFee,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'finished_date': finishedDate?.toIso8601String(),
      'collected_amount': collectedAmount,
      'balance_amount': balanceAmount,
      'status': status,
      'is_target_customer': isTargetCustomer ? 1 : 0,
    };
  }

  LoanModel copyWith({
    int? id,
    String? bondNumber,
    String? lineCode,
    int? customerId,
    CustomerModel? customer,
    String? customerName,
    String? fatherOrSpouseName,
    String? phoneNumber,
    String? address,
    String? city,
    String? photoPath,
    String? proofType,
    String? proofFrontPath,
    String? proofBackPath,
    int? tenureDays,
    double? loanAmount,
    double? interestRate,
    double? interestAmount,
    double? totalAmount,
    double? dailyDueAmount,
    double? chitFee,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? finishedDate,
    double? collectedAmount,
    double? balanceAmount,
    String? status,
    bool? isTargetCustomer,
  }) {
    return LoanModel(
      id: id ?? this.id,
      bondNumber: bondNumber ?? this.bondNumber,
      lineCode: lineCode ?? this.lineCode,
      customerId: customerId ?? this.customerId,
      customer: customer ?? this.customer,
      customerName: customerName ?? this.customerName,
      fatherOrSpouseName: fatherOrSpouseName ?? this.fatherOrSpouseName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      city: city ?? this.city,
      photoPath: photoPath ?? this.photoPath,
      proofType: proofType ?? this.proofType,
      proofFrontPath: proofFrontPath ?? this.proofFrontPath,
      proofBackPath: proofBackPath ?? this.proofBackPath,
      tenureDays: tenureDays ?? this.tenureDays,
      loanAmount: loanAmount ?? this.loanAmount,
      interestRate: interestRate ?? this.interestRate,
      interestAmount: interestAmount ?? this.interestAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      dailyDueAmount: dailyDueAmount ?? this.dailyDueAmount,
      chitFee: chitFee ?? this.chitFee,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      finishedDate: finishedDate ?? this.finishedDate,
      collectedAmount: collectedAmount ?? this.collectedAmount,
      balanceAmount: balanceAmount ?? this.balanceAmount,
      status: status ?? this.status,
      isTargetCustomer: isTargetCustomer ?? this.isTargetCustomer,
    );
  }
}

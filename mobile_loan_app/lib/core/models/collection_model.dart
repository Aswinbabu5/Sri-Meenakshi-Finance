class CollectionModel {
  final int id;
  final int loanId;
  final String bondNumber;
  final String lineCode;
  final String customerName;
  final DateTime collectionDate;
  final double amount;
  final double previousBalance;
  final double currentBalance;
  final String receiptType; // 'Note' or 'Chit'
  final String paymentMode; // 'Cash' or 'Online' (GPay, PhonePe, UPI)
  final String? notes;

  CollectionModel({
    required this.id,
    required this.loanId,
    required this.bondNumber,
    required this.lineCode,
    required this.customerName,
    required this.collectionDate,
    required this.amount,
    required this.previousBalance,
    required this.currentBalance,
    this.receiptType = 'Note',
    this.paymentMode = 'Cash',
    this.notes,
  });

  bool get isOnline => paymentMode.toLowerCase() == 'online';
  bool get isCash => paymentMode.toLowerCase() != 'online';

  factory CollectionModel.fromJson(Map<String, dynamic> json) {
    return CollectionModel(
      id: json['id'] ?? 0,
      loanId: json['loanId'] ?? json['loan_id'] ?? 0,
      bondNumber: json['bondNumber'] ?? json['bond_number'] ?? '',
      lineCode: json['lineCode'] ?? json['line_code'] ?? 'A',
      customerName: json['customerName'] ?? json['customer_name'] ?? json['loan']?['customer']?['name'] ?? '',
      collectionDate: json['collectionDate'] != null
          ? DateTime.tryParse(json['collectionDate']) ?? DateTime.now()
          : (json['collection_date'] != null ? DateTime.tryParse(json['collection_date']) ?? DateTime.now() : DateTime.now()),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      previousBalance: (json['previousBalance'] ?? json['previous_balance'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (json['currentBalance'] ?? json['current_balance'] as num?)?.toDouble() ?? 0.0,
      receiptType: json['receiptType'] ?? json['receipt_type'] ?? 'Note',
      paymentMode: json['paymentMode'] ?? json['payment_mode'] ?? 'Cash',
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'loanId': loanId,
      'bondNumber': bondNumber,
      'lineCode': lineCode,
      'customerName': customerName,
      'collectionDate': collectionDate.toIso8601String(),
      'amount': amount,
      'previousBalance': previousBalance,
      'currentBalance': currentBalance,
      'receiptType': receiptType,
      'paymentMode': paymentMode,
      'notes': notes,
    };
  }

  Map<String, dynamic> toDbMap() {
    return {
      if (id > 0) 'id': id,
      'loan_id': loanId,
      'bond_number': bondNumber,
      'line_code': lineCode,
      'customer_name': customerName,
      'collection_date': collectionDate.toIso8601String(),
      'amount': amount,
      'previous_balance': previousBalance,
      'current_balance': currentBalance,
      'receipt_type': receiptType,
      'payment_mode': paymentMode,
      'notes': notes,
    };
  }
}

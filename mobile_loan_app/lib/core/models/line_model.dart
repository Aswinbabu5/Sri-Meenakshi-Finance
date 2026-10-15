class LineModel {
  final String lineCode;
  final String lineName;
  final String collectorName;
  final String? description;
  final int activeLoans;
  final double totalBalance;
  final double todayCollection;

  LineModel({
    required this.lineCode,
    required this.lineName,
    required this.collectorName,
    this.description,
    this.activeLoans = 0,
    this.totalBalance = 0,
    this.todayCollection = 0,
  });

  factory LineModel.fromJson(Map<String, dynamic> json) {
    return LineModel(
      lineCode: json['lineCode'] ?? json['line_code'] ?? 'A',
      lineName: json['lineName'] ?? json['line_name'] ?? 'Line A',
      collectorName: json['collectorName'] ?? json['collector_name'] ?? '',
      description: json['description'],
      activeLoans: json['activeLoans'] ?? json['active_loans'] ?? 0,
      totalBalance: (json['totalBalance'] ?? json['total_balance'] as num?)?.toDouble() ?? 0.0,
      todayCollection: (json['todayCollection'] ?? json['today_collection'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'line_code': lineCode,
      'line_name': lineName,
      'collector_name': collectorName,
      'description': description,
    };
  }
}

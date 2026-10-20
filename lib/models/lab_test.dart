class LabTest {
  final int? id;
  final int visitId;
  final String section;      // e.g. "Thyroid Function Tests"
  final String testName;     // e.g. "T3 Total"
  final String result;
  final String unit;
  final String normalRange;
  final String notes;
  final String status;       // "Pending" or "Final"
  final String reportingTime;
  final double price;        // Rs

  LabTest({
    this.id,
    required this.visitId,
    this.section = '',
    required this.testName,
    this.result = '',
    this.unit = '',
    this.normalRange = '',
    this.notes = '',
    this.status = 'Pending',
    this.reportingTime = '',
    this.price = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'visit_id': visitId,
      'section': section,
      'test_name': testName,
      'result': result,
      'unit': unit,
      'normal_range': normalRange,
      'notes': notes,
      'status': status,
      'reporting_time': reportingTime,
      'price': price,
    };
  }

  factory LabTest.fromMap(Map<String, dynamic> map) {
    return LabTest(
      id: map['id'] as int?,
      visitId: map['visit_id'] as int? ?? 0,
      section: map['section'] as String? ?? '',
      testName: map['test_name'] as String? ?? '',
      result: map['result'] as String? ?? '',
      unit: map['unit'] as String? ?? '',
      normalRange: map['normal_range'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      status: map['status'] as String? ?? 'Pending',
      reportingTime: map['reporting_time'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
    );
  }

  LabTest copyWith({
    int? id,
    int? visitId,
    String? section,
    String? testName,
    String? result,
    String? unit,
    String? normalRange,
    String? notes,
    String? status,
    String? reportingTime,
    double? price,
  }) {
    return LabTest(
      id: id ?? this.id,
      visitId: visitId ?? this.visitId,
      section: section ?? this.section,
      testName: testName ?? this.testName,
      result: result ?? this.result,
      unit: unit ?? this.unit,
      normalRange: normalRange ?? this.normalRange,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      reportingTime: reportingTime ?? this.reportingTime,
      price: price ?? this.price,
    );
  }

  bool get isFinal => status.toLowerCase() == 'final';
  bool get isPending => !isFinal;
}
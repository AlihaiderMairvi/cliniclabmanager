class Visit {
  final int? id;
  final int patientId;
  final String pin;
  final String visitDate;
  final String referredBy;
  final String createdAt;

  // Invoice fields (Phase 3)
  final double discount;         // Rs
  final double amountReceived;   // Rs
  final String paymentMode;      // Cash / Card / Easypaisa / JazzCash / Bank Transfer / Credit
  final String invoiceNotes;

  Visit({
    this.id,
    required this.patientId,
    required this.pin,
    required this.visitDate,
    this.referredBy = 'Self',
    this.createdAt = '',
    this.discount = 0,
    this.amountReceived = 0,
    this.paymentMode = 'Cash',
    this.invoiceNotes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'patient_id': patientId,
      'pin': pin,
      'visit_date': visitDate,
      'referred_by': referredBy,
      'created_at': createdAt,
      'discount': discount,
      'amount_received': amountReceived,
      'payment_mode': paymentMode,
      'invoice_notes': invoiceNotes,
    };
  }

  factory Visit.fromMap(Map<String, dynamic> map) {
    return Visit(
      id: map['id'] as int?,
      patientId: map['patient_id'] as int? ?? 0,
      pin: map['pin'] as String? ?? '',
      visitDate: map['visit_date'] as String? ?? '',
      referredBy: map['referred_by'] as String? ?? 'Self',
      createdAt: map['created_at'] as String? ?? '',
      discount: (map['discount'] as num?)?.toDouble() ?? 0,
      amountReceived: (map['amount_received'] as num?)?.toDouble() ?? 0,
      paymentMode: map['payment_mode'] as String? ?? 'Cash',
      invoiceNotes: map['invoice_notes'] as String? ?? '',
    );
  }

  /// Short date like "05-Oct-2026" for display.
  String get displayDate {
    if (visitDate.length < 10) return visitDate;
    final datePart = visitDate.substring(0, 10);
    try {
      final d = DateTime.parse(datePart);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${d.day.toString().padLeft(2, '0')}-'
          '${months[d.month - 1]}-'
          '${d.year}';
    } catch (_) {
      return datePart;
    }
  }

  Visit copyWith({
    int? id,
    int? patientId,
    String? pin,
    String? visitDate,
    String? referredBy,
    String? createdAt,
    double? discount,
    double? amountReceived,
    String? paymentMode,
    String? invoiceNotes,
  }) {
    return Visit(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      pin: pin ?? this.pin,
      visitDate: visitDate ?? this.visitDate,
      referredBy: referredBy ?? this.referredBy,
      createdAt: createdAt ?? this.createdAt,
      discount: discount ?? this.discount,
      amountReceived: amountReceived ?? this.amountReceived,
      paymentMode: paymentMode ?? this.paymentMode,
      invoiceNotes: invoiceNotes ?? this.invoiceNotes,
    );
  }
}
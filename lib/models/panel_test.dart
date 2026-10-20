class PanelTest {
  final int? id;
  final int panelId;
  final String section;      // e.g. "CBC" or "Diff.Leuc.Count (DLC)"
  final String testName;     // e.g. "WBC"
  final String unit;         // e.g. "x 10^9/L"
  final String normalRange;  // e.g. "(M: 4.0-10.0) (F: 4.0-10.0)"
  final int displayOrder;
  final double price;        // Rs, flat (no decimals in UI)

  PanelTest({
    this.id,
    required this.panelId,
    this.section = '',
    required this.testName,
    this.unit = '',
    this.normalRange = '',
    this.displayOrder = 0,
    this.price = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'panel_id': panelId,
      'section': section,
      'test_name': testName,
      'unit': unit,
      'normal_range': normalRange,
      'display_order': displayOrder,
      'price': price,
    };
  }

  factory PanelTest.fromMap(Map<String, dynamic> map) {
    return PanelTest(
      id: map['id'] as int?,
      panelId: map['panel_id'] as int? ?? 0,
      section: map['section'] as String? ?? '',
      testName: map['test_name'] as String? ?? '',
      unit: map['unit'] as String? ?? '',
      normalRange: map['normal_range'] as String? ?? '',
      displayOrder: map['display_order'] as int? ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0,
    );
  }

  PanelTest copyWith({
    int? id,
    int? panelId,
    String? section,
    String? testName,
    String? unit,
    String? normalRange,
    int? displayOrder,
    double? price,
  }) {
    return PanelTest(
      id: id ?? this.id,
      panelId: panelId ?? this.panelId,
      section: section ?? this.section,
      testName: testName ?? this.testName,
      unit: unit ?? this.unit,
      normalRange: normalRange ?? this.normalRange,
      displayOrder: displayOrder ?? this.displayOrder,
      price: price ?? this.price,
    );
  }
}
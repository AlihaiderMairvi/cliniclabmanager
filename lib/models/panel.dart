class Panel {
  final int? id;
  final String name;      // e.g. "CBC", "LFT", "Lipid Profile"
  final String createdAt;

  Panel({
    this.id,
    required this.name,
    this.createdAt = '',
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'created_at': createdAt,
    };
  }

  factory Panel.fromMap(Map<String, dynamic> map) {
    return Panel(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      createdAt: map['created_at'] as String? ?? '',
    );
  }

  Panel copyWith({int? id, String? name, String? createdAt}) {
    return Panel(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
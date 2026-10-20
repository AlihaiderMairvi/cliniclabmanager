class Patient {
  final int? id;
  final String name;
  final String age;
  final String gender;
  final String phone;
  final String address;
  final String dateAdded;

  Patient({
    this.id,
    required this.name,
    this.age = '',
    this.gender = '',
    this.phone = '',
    this.address = '',
    required this.dateAdded,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'age': age,
      'gender': gender,
      'phone': phone,
      'address': address,
      'date_added': dateAdded,
    };
  }

  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      age: map['age'] as String? ?? '',
      gender: map['gender'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String? ?? '',
      dateAdded: map['date_added'] as String? ?? '',
    );
  }

  String get displayLabel => phone.isNotEmpty ? '$name ($phone)' : name;
}
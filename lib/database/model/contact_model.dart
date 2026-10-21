const String idColumn = 'idColumn';
const String nameColumn = 'nameColumn';
const String emailColumn = 'emailColumn';
const String phoneColumn = 'phoneColumn';
const String imgColumn = 'imgColumn';
const String contactTable = 'contactTable';
const addressColumns = [
  'cep',
  'street',
  'neighborhood',
  'city',
  'uf',
  'number',
  'complement',
];

class Contact {
  Contact({
    this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.img,
    this.cep = '',
    this.street = '',
    this.neighborhood = '',
    this.city = '',
    this.uf = '',
    this.number = '',
    this.complement = '',
  });

  int? id;
  String name;
  String email;
  String phone;
  String? img;
  String cep;
  String street;
  String neighborhood;
  String city;
  String uf;
  String number;
  String complement;

  String get addressLabel => [
    [street, number, complement].where((s) => s.isNotEmpty).join(', '),
    [
      neighborhood,
      [city, uf].where((s) => s.isNotEmpty).join('/'),
    ].where((s) => s.isNotEmpty).join(' — '),
    if (cep.isNotEmpty) 'CEP $cep',
  ].where((s) => s.isNotEmpty).join('\n');

  Contact.fromMap(Map<String, dynamic> map)
    : id = map[idColumn] as int?,
      name = map[nameColumn] as String,
      email = map[emailColumn] as String,
      phone = map[phoneColumn] as String,
      img = map[imgColumn] as String?,
      cep = map['cep'] as String? ?? '',
      street = map['street'] as String? ?? '',
      neighborhood = map['neighborhood'] as String? ?? '',
      city = map['city'] as String? ?? '',
      uf = map['uf'] as String? ?? '',
      number = map['number'] as String? ?? '',
      complement = map['complement'] as String? ?? '';

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      nameColumn: name,
      emailColumn: email,
      phoneColumn: phone,
      imgColumn: img,
      'cep': cep,
      'street': street,
      'neighborhood': neighborhood,
      'city': city,
      'uf': uf,
      'number': number,
      'complement': complement,
    };
    if (id != null) map[idColumn] = id;
    return map;
  }

  @override
  String toString() =>
      'Contact(id: $id, name: $name, email: $email, phone: $phone, img: $img)';
}

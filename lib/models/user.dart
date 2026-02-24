class User {
  final String id;
  final String name;
  final int age;
  final String bio;
  final String location;
  final List<String> photos;
  final List<String> interests;
  final String gender;
  final String lookingFor;

  /// AI/profile-generation metadata (ONE PROFILE = ONE PERSON = ONE FACE)
  ///
  /// These are optional and safe to leave null if your `profiles` table hasn’t been
  /// migrated yet.
  final String? characterName;
  final String? generationPlatform;
  final String? seedNumber;
  final DateTime? identityCreatedAt;
  final String? identityNotes;

  final String? phone;
  final DateTime? dateOfBirth;
  final String? country;
  final String? city;
  final String? profession;
  final String? tribe;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    required this.id,
    required this.name,
    required this.age,
    required this.bio,
    required this.location,
    required this.photos,
    required this.interests,
    required this.gender,
    required this.lookingFor,
    this.characterName,
    this.generationPlatform,
    this.seedNumber,
    this.identityCreatedAt,
    this.identityNotes,
    this.phone,
    this.dateOfBirth,
    this.country,
    this.city,
    this.profession,
    this.tribe,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'bio': bio,
        'location': location,
        'photos': photos,
        'interests': interests,
        'gender': gender,
        'lookingFor': lookingFor,
        'characterName': characterName,
        'generationPlatform': generationPlatform,
        'seedNumber': seedNumber,
        'identityCreatedAt': identityCreatedAt?.toIso8601String(),
        'identityNotes': identityNotes,
        'phone': phone,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'country': country,
        'city': city,
        'profession': profession,
        'tribe': tribe,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory User.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) {
        try {
          return DateTime.parse(v);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    return User(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'User').toString(),
      age: (json['age'] is int) ? (json['age'] as int) : int.tryParse('${json['age']}') ?? 18,
      bio: (json['bio'] ?? '').toString(),
      location: (json['location'] ?? 'Location not set').toString(),
      photos: (json['photos'] is List) ? List<String>.from(json['photos']) : const <String>[],
      interests: (json['interests'] is List) ? List<String>.from(json['interests']) : const <String>[],
      gender: (json['gender'] ?? 'Not specified').toString(),
      lookingFor: (json['lookingFor'] ?? 'Not specified').toString(),
      characterName: (json['characterName'] as String?),
      generationPlatform: (json['generationPlatform'] as String?),
      seedNumber: (json['seedNumber'] ?? '').toString().trim().isEmpty ? null : (json['seedNumber'] ?? '').toString(),
      identityCreatedAt: parseDate(json['identityCreatedAt']),
      identityNotes: (json['identityNotes'] as String?),
      phone: (json['phone'] as String?)?.trim().isEmpty == true ? null : (json['phone'] as String?),
      dateOfBirth: parseDate(json['dateOfBirth']),
      country: (json['country'] as String?),
      city: (json['city'] as String?),
      profession: (json['profession'] as String?),
      tribe: (json['tribe'] as String?),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }

  User copyWith({
    String? id,
    String? name,
    int? age,
    String? bio,
    String? location,
    List<String>? photos,
    List<String>? interests,
    String? gender,
    String? lookingFor,
    String? characterName,
    String? generationPlatform,
    String? seedNumber,
    DateTime? identityCreatedAt,
    String? identityNotes,
    String? phone,
    DateTime? dateOfBirth,
    String? country,
    String? city,
    String? profession,
    String? tribe,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      User(
        id: id ?? this.id,
        name: name ?? this.name,
        age: age ?? this.age,
        bio: bio ?? this.bio,
        location: location ?? this.location,
        photos: photos ?? this.photos,
        interests: interests ?? this.interests,
        gender: gender ?? this.gender,
        lookingFor: lookingFor ?? this.lookingFor,
        characterName: characterName ?? this.characterName,
        generationPlatform: generationPlatform ?? this.generationPlatform,
        seedNumber: seedNumber ?? this.seedNumber,
        identityCreatedAt: identityCreatedAt ?? this.identityCreatedAt,
        identityNotes: identityNotes ?? this.identityNotes,
        phone: phone ?? this.phone,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        country: country ?? this.country,
        city: city ?? this.city,
        profession: profession ?? this.profession,
        tribe: tribe ?? this.tribe,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

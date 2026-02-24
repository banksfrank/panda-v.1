import 'dart:math';

class SeededIdentity {
  /// Locked base seed for the entire app. One number = one deterministic identity space.
  static const String lockedBaseSeed = '847392';

  /// Demographic constraints requested:
  /// - Total countries: provided list (small/medium/large) with weighted distribution.
  /// - Gender split per country: 90% Male / 10% Female.
  /// - Age range: 18–90.

  final String seed;
  final String personId;
  final String id;
  final String name;
  final int age;
  final String bio;
  final String location;
  final String? country;
  final String? city;
  final String? profession;
  final List<String> interests;
  final String gender;
  final String lookingFor;
  final String ethnicity;
  final List<String> photos;

  const SeededIdentity({
    required this.seed,
    required this.personId,
    required this.id,
    required this.name,
    required this.age,
    required this.bio,
    required this.location,
    required this.country,
    required this.city,
    required this.profession,
    required this.interests,
    required this.gender,
    required this.lookingFor,
    required this.ethnicity,
    required this.photos,
  });

  static SeededIdentity build({required String seed, required String personId, String? country, String? city, int photosPerProfile = 3}) {
    final material = '$seed|$personId';
    final seedInt = _fnv1a32(material);
    final rng = Random(seedInt);

    final geo = _resolveGeo(seed: seed, personId: personId, country: country, city: city);

    const firstNamesW = ['Amina', 'Zara', 'Nia', 'Tola', 'Imani', 'Sade', 'Lerato', 'Nandi', 'Amara', 'Chioma', 'Asha', 'Ayana'];
    const firstNamesM = ['Noah', 'Ethan', 'Kofi', 'Tunde', 'Malik', 'Kwame', 'Ade', 'Siyabonga', 'Emeka', 'Jabari', 'Sefu', 'Thabo'];
    const professions = ['Software Engineer', 'Product Designer', 'Nurse', 'Teacher', 'Analyst', 'Entrepreneur', 'Marketing', 'Photographer', 'Lawyer', 'Chef'];
    const interestsPool = ['Coffee', 'Travel', 'Afrobeats', 'Movies', 'Fitness', 'Food', 'Museums', 'Hiking', 'Books', 'Gaming', 'Photography', 'Live music'];
    const lookingForPool = ['Dating', 'Relationship', 'Friends'];
    const ethnicityPool = ['Black', 'White', 'Latino', 'Middle Eastern', 'South Asian', 'East Asian', 'Southeast Asian'];

    // 90% Male / 10% Female (deterministic per-country).
    // We derive gender from (seed + personId + resolved country) so distribution is stable within each country.
    final genderRng = Random(_fnv1a32('$seed|$personId|${geo.country}|gender'));
    final gender = genderRng.nextDouble() < 0.10 ? 'Female' : 'Male';
    final name = gender == 'Female' ? firstNamesW[rng.nextInt(firstNamesW.length)] : firstNamesM[rng.nextInt(firstNamesM.length)];

    // 18–90 inclusive.
    final age = 18 + rng.nextInt(73);

    final profession = professions[rng.nextInt(professions.length)];
    final lookingFor = lookingForPool[rng.nextInt(lookingForPool.length)];
    final ethnicity = ethnicityPool[rng.nextInt(ethnicityPool.length)];

    final chosenInterests = <String>{};
    while (chosenInterests.length < 4) {
      chosenInterests.add(interestsPool[rng.nextInt(interestsPool.length)]);
    }

    const bios = [
      'Coffee dates, good playlists, and spontaneous weekend plans.',
      'Quiet confidence, big laughs. Ask me about my latest obsession.',
      'Gym sometimes, food always. Looking for someone kind and curious.',
      'Bookstore afternoons + live music nights. Let’s make it fun.',
    ];

    final bio = '${bios[rng.nextInt(bios.length)]}\n\n$profession • ${geo.city}';

    final seedKeyBase = _seedKeyFromFNV(material);
    final photos = <String>[];
    for (var i = 0; i < photosPerProfile; i++) {
      final suffix = String.fromCharCode('a'.codeUnitAt(0) + (i % 26));
      photos.add('https://picsum.photos/seed/$seedKeyBase-$suffix/900/1200');
    }

    return SeededIdentity(
      seed: seed,
      personId: personId,
      id: 'seedv2_${seedKeyBase.substring(0, 12)}',
      name: name,
      age: age,
      bio: bio,
      location: '${geo.city}, ${geo.country}',
      country: geo.country,
      city: geo.city,
      profession: profession,
      interests: chosenInterests.toList(growable: false),
      gender: gender,
      lookingFor: lookingFor,
      ethnicity: ethnicity,
      photos: photos,
    );
  }

  static ({String country, String city}) _resolveGeo({required String seed, required String personId, required String? country, required String? city}) {
    if ((country ?? '').trim().isNotEmpty && (city ?? '').trim().isNotEmpty) return (country: country!.trim(), city: city!.trim());

    final material = '$seed|$personId|geo';
    final rng = Random(_fnv1a32(material));

    // Weighted country distribution by bucket:
    // - Small countries: weight 1
    // - Medium countries: weight 2
    // - Large countries: weight 3
    // Total Countries: 35 (8 small + 21 medium + 6 large).
    const small = ['Norway', 'Rwanda', 'Qatar', 'Singapore', 'Botswana', 'Namibia', 'Zambia', 'Tunisia'];
    const medium = [
      'UK',
      'France',
      'Uganda',
      'Kenya',
      'Tanzania',
      'Germany',
      'Netherlands',
      'Spain',
      'Italy',
      'Sweden',
      'UAE',
      'Philippines',
      'Indonesia',
      'Canada',
      'Argentina',
      'Ghana',
      'Senegal',
      'Egypt',
      'Morocco',
      'Zimbabwe',
      'Cameroon',
    ];
    const large = ['USA', 'South Africa', 'India', 'Brazil', 'Mexico', 'Nigeria'];

    final bucketRoll = rng.nextInt(1 + 2 + 3);
    final bucket = bucketRoll < 1 ? 'small' : (bucketRoll < 1 + 2 ? 'medium' : 'large');
    final chosenCountry = switch (bucket) {
      'small' => small[rng.nextInt(small.length)],
      'medium' => medium[rng.nextInt(medium.length)],
      _ => large[rng.nextInt(large.length)],
    };

    final chosenCity = _pickCityForCountry(chosenCountry, rng);
    return (country: (country ?? chosenCountry).trim().isEmpty ? chosenCountry : country!.trim(), city: (city ?? chosenCity).trim().isEmpty ? chosenCity : city!.trim());
  }

  static String _pickCityForCountry(String country, Random rng) {
    const cities = <String, List<String>>{
      'Norway': ['Oslo', 'Bergen'],
      'Rwanda': ['Kigali'],
      'Qatar': ['Doha'],
      'Singapore': ['Singapore'],
      'Botswana': ['Gaborone'],
      'Namibia': ['Windhoek'],
      'Zambia': ['Lusaka'],
      'Tunisia': ['Tunis', 'Sfax'],
      'UK': ['London', 'Manchester', 'Birmingham'],
      'France': ['Paris', 'Lyon', 'Marseille'],
      'Uganda': ['Kampala'],
      'Kenya': ['Nairobi', 'Mombasa'],
      'Tanzania': ['Dar es Salaam', 'Arusha'],
      'Germany': ['Berlin', 'Hamburg', 'Munich'],
      'Netherlands': ['Amsterdam', 'Rotterdam'],
      'Spain': ['Madrid', 'Barcelona', 'Valencia'],
      'Italy': ['Milan', 'Rome', 'Naples'],
      'Sweden': ['Stockholm', 'Gothenburg'],
      'UAE': ['Dubai', 'Abu Dhabi'],
      'Philippines': ['Manila', 'Cebu'],
      'Indonesia': ['Jakarta', 'Bali'],
      'Canada': ['Toronto', 'Vancouver', 'Montreal'],
      'Argentina': ['Buenos Aires', 'Córdoba'],
      'Ghana': ['Accra', 'Kumasi'],
      'Senegal': ['Dakar'],
      'Egypt': ['Cairo', 'Alexandria'],
      'Morocco': ['Casablanca', 'Marrakesh'],
      'Zimbabwe': ['Harare'],
      'Cameroon': ['Douala', 'Yaoundé'],
      'USA': ['New York', 'Los Angeles', 'Chicago'],
      'South Africa': ['Johannesburg', 'Cape Town', 'Durban'],
      'India': ['Mumbai', 'Delhi', 'Bangalore'],
      'Brazil': ['São Paulo', 'Rio de Janeiro'],
      'Mexico': ['Mexico City', 'Guadalajara'],
      'Nigeria': ['Lagos', 'Abuja'],
    };

    final list = cities[country];
    if (list == null || list.isEmpty) return 'City';
    return list[rng.nextInt(list.length)];
  }

  static int _fnv1a32(String input) {
    var h = 0x811c9dc5;
    for (final codeUnit in input.codeUnits) {
      h ^= codeUnit;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  static String _seedKeyFromFNV(String material) {
    final h = _fnv1a32(material);
    final hex = h.toRadixString(16).padLeft(8, '0');
    return 'panda-$hex';
  }
}

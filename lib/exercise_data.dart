class ExerciseCalculator {
  static const Map<String, dynamic> constants = {
    "size_rules": {
      "small": {"max_weight_kg": 9.99, "multiplier": 0.8, "pace_kmh": 3.0},
      "medium": {"max_weight_kg": 24.99, "multiplier": 1.0, "pace_kmh": 4.0},
      "large": {"min_weight_kg": 25.0, "multiplier": 1.2, "pace_kmh": 5.0}
    },
    "brachycephalic_rules": {"factor_multiplier": 0.75, "pace_cap_kmh": 3.0},
    "age_factors": {"puppy": 0.7, "adult": 1.0, "senior": 0.6},
    "owner_activity_multipliers": {"low": 0.8, "moderate": 1.0, "high": 1.2}
  };

  static const Map<String, Map<String, dynamic>> breedData = {
    "Affenpinscher": {"is_brachycephalic": true, "breed_energy": 65},
    "Afghan Hound": {"is_brachycephalic": false, "breed_energy": 80},
    "Airedale Terrier": {"is_brachycephalic": false, "breed_energy": 80},
    "Akita": {"is_brachycephalic": false, "breed_energy": 80},
    "Alaskan Malamute": {"is_brachycephalic": false, "breed_energy": 110},
    "American Bulldog": {"is_brachycephalic": true, "breed_energy": 80},
    "American Eskimo": {"is_brachycephalic": false, "breed_energy": 80},
    "American Foxhound": {"is_brachycephalic": false, "breed_energy": 95},
    "Australian Cattle Dog": {"is_brachycephalic": false, "breed_energy": 95},
    "Australian Shepherd": {"is_brachycephalic": false, "breed_energy": 95},
    "Australian Terrier": {"is_brachycephalic": false, "breed_energy": 65},
    "Basenji": {"is_brachycephalic": false, "breed_energy": 80},
    "Basset Hound": {"is_brachycephalic": false, "breed_energy": 50},
    "Beagle": {"is_brachycephalic": false, "breed_energy": 80},
    "Bearded Collie": {"is_brachycephalic": false, "breed_energy": 80},
    "Bernese Mountain Dog": {"is_brachycephalic": false, "breed_energy": 65},
    "Bichon Frise": {"is_brachycephalic": false, "breed_energy": 50},
    "Black Russian Terrier": {"is_brachycephalic": false, "breed_energy": 80},
    "Bloodhound": {"is_brachycephalic": false, "breed_energy": 80},
    "Border Collie": {"is_brachycephalic": false, "breed_energy": 110},
    "Border Terrier": {"is_brachycephalic": false, "breed_energy": 65},
    "Borzoi": {"is_brachycephalic": false, "breed_energy": 80},
    "Boston Terrier": {"is_brachycephalic": true, "breed_energy": 65},
    "Bouvier des Flandres": {"is_brachycephalic": false, "breed_energy": 80},
    "Boxer": {"is_brachycephalic": true, "breed_energy": 80},
    "Briard": {"is_brachycephalic": false, "breed_energy": 80},
    "Brittany": {"is_brachycephalic": false, "breed_energy": 95},
    "Brussels Griffon": {"is_brachycephalic": true, "breed_energy": 65},
    "Bull Terrier": {"is_brachycephalic": false, "breed_energy": 80},
    "Bullmastiff": {"is_brachycephalic": true, "breed_energy": 65},
    "Cairn Terrier": {"is_brachycephalic": false, "breed_energy": 65},
    "Canaan Dog": {"is_brachycephalic": false, "breed_energy": 80},
    "Cane Corso": {"is_brachycephalic": true, "breed_energy": 80},
    "Cardigan Welsh Corgi": {"is_brachycephalic": false, "breed_energy": 80},
    "Cavalier King Charles Spaniel": {"is_brachycephalic": true, "breed_energy": 50},
    "Chesapeake Bay Retriever": {"is_brachycephalic": false, "breed_energy": 95},
    "Chihuahua": {"is_brachycephalic": false, "breed_energy": 50},
    "Chinese Crested": {"is_brachycephalic": false, "breed_energy": 50},
    "Chinese Shar-Pei": {"is_brachycephalic": true, "breed_energy": 65},
    "Chow Chow": {"is_brachycephalic": true, "breed_energy": 65},
    "Clumber Spaniel": {"is_brachycephalic": false, "breed_energy": 65},
    "Cocker Spaniel": {"is_brachycephalic": false, "breed_energy": 65},
    "Collie": {"is_brachycephalic": false, "breed_energy": 80},
    "Curly-Coated Retriever": {"is_brachycephalic": false, "breed_energy": 80},
    "Dachshund": {"is_brachycephalic": false, "breed_energy": 65},
    "Dalmatian": {"is_brachycephalic": false, "breed_energy": 95},
    "Dandie Dinmont Terrier": {"is_brachycephalic": false, "breed_energy": 65},
    "Doberman Pinscher": {"is_brachycephalic": false, "breed_energy": 95},
    "English Bulldog": {"is_brachycephalic": true, "breed_energy": 50},
    "English Cocker Spaniel": {"is_brachycephalic": false, "breed_energy": 65},
    "English Foxhound": {"is_brachycephalic": false, "breed_energy": 95},
    "English Setter": {"is_brachycephalic": false, "breed_energy": 80},
    "English Springer Spaniel": {"is_brachycephalic": false, "breed_energy": 80},
    "English Toy Spaniel": {"is_brachycephalic": true, "breed_energy": 50},
    "Entlebucher Mountain Dog": {"is_brachycephalic": false, "breed_energy": 95},
    "Field Spaniel": {"is_brachycephalic": false, "breed_energy": 80},
    "Finnish Lapphund": {"is_brachycephalic": false, "breed_energy": 80},
    "Finnish Spitz": {"is_brachycephalic": false, "breed_energy": 80},
    "Flat-Coated Retriever": {"is_brachycephalic": false, "breed_energy": 95},
    "French Bulldog": {"is_brachycephalic": true, "breed_energy": 50},
    "German Pinscher": {"is_brachycephalic": false, "breed_energy": 80},
    "German Shepherd": {"is_brachycephalic": false, "breed_energy": 95},
    "German Shorthaired Pointer": {"is_brachycephalic": false, "breed_energy": 95},
    "German Wirehaired Pointer": {"is_brachycephalic": false, "breed_energy": 95},
    "Giant Schnauzer": {"is_brachycephalic": false, "breed_energy": 80},
    "Golden Retriever": {"is_brachycephalic": false, "breed_energy": 80},
    "Gordon Setter": {"is_brachycephalic": false, "breed_energy": 80},
    "Great Dane": {"is_brachycephalic": false, "breed_energy": 80},
    "Great Pyrenees": {"is_brachycephalic": false, "breed_energy": 65},
    "Greater Swiss Mountain Dog": {"is_brachycephalic": false, "breed_energy": 80},
    "Greyhound": {"is_brachycephalic": false, "breed_energy": 80},
    "Harrier": {"is_brachycephalic": false, "breed_energy": 80},
    "Havanese": {"is_brachycephalic": false, "breed_energy": 65},
    "Ibizan Hound": {"is_brachycephalic": false, "breed_energy": 80},
    "Icelandic Sheepdog": {"is_brachycephalic": false, "breed_energy": 80},
    "Irish Red and White Setter": {"is_brachycephalic": false, "breed_energy": 95},
    "Irish Setter": {"is_brachycephalic": false, "breed_energy": 95},
    "Irish Terrier": {"is_brachycephalic": false, "breed_energy": 65},
    "Irish Water Spaniel": {"is_brachycephalic": false, "breed_energy": 80},
    "Irish Wolfhound": {"is_brachycephalic": false, "breed_energy": 80},
    "Italian Greyhound": {"is_brachycephalic": false, "breed_energy": 65},
    "Japanese Chin": {"is_brachycephalic": true, "breed_energy": 50},
    "Japanese Spitz": {"is_brachycephalic": false, "breed_energy": 65},
    "Keeshond": {"is_brachycephalic": false, "breed_energy": 65},
    "Kerry Blue Terrier": {"is_brachycephalic": false, "breed_energy": 65},
    "Komondor": {"is_brachycephalic": false, "breed_energy": 80},
    "Kuvasz": {"is_brachycephalic": false, "breed_energy": 80},
    "Labrador Retriever": {"is_brachycephalic": false, "breed_energy": 80},
    "Lakeland Terrier": {"is_brachycephalic": false, "breed_energy": 65},
    "Leonberger": {"is_brachycephalic": false, "breed_energy": 80},
    "Lhasa Apso": {"is_brachycephalic": true, "breed_energy": 50},
    "Lowchen": {"is_brachycephalic": false, "breed_energy": 65},
    "Maltese": {"is_brachycephalic": false, "breed_energy": 50},
    "Manchester Terrier": {"is_brachycephalic": false, "breed_energy": 65},
    "Mastiff": {"is_brachycephalic": true, "breed_energy": 65},
    "Miniature Pinscher": {"is_brachycephalic": false, "breed_energy": 65},
    "Miniature Schnauzer": {"is_brachycephalic": false, "breed_energy": 65},
    "Neapolitan Mastiff": {"is_brachycephalic": true, "breed_energy": 50},
    "Newfoundland": {"is_brachycephalic": false, "breed_energy": 80},
    "Norfolk Terrier": {"is_brachycephalic": false, "breed_energy": 65},
    "Norwegian Buhund": {"is_brachycephalic": false, "breed_energy": 80},
    "Norwegian Elkhound": {"is_brachycephalic": false, "breed_energy": 80},
    "Norwegian Lundehund": {"is_brachycephalic": false, "breed_energy": 80},
    "Old English Sheepdog": {"is_brachycephalic": false, "breed_energy": 80},
    "Otterhound": {"is_brachycephalic": false, "breed_energy": 95},
    "Papillon": {"is_brachycephalic": false, "breed_energy": 50},
    "Pekingese": {"is_brachycephalic": true, "breed_energy": 50},
    "Pembroke Welsh Corgi": {"is_brachycephalic": false, "breed_energy": 80},
    "Petit Basset Griffon Vendeen": {"is_brachycephalic": false, "breed_energy": 80},
    "Pharaoh Hound": {"is_brachycephalic": false, "breed_energy": 80},
    "Pointer": {"is_brachycephalic": false, "breed_energy": 95},
    "Pomeranian": {"is_brachycephalic": false, "breed_energy": 50},
    "Poodle (Miniature)": {"is_brachycephalic": false, "breed_energy": 65},
    "Poodle (Standard)": {"is_brachycephalic": false, "breed_energy": 80},
    "Poodle (Toy)": {"is_brachycephalic": false, "breed_energy": 50},
    "Portuguese Podengo": {"is_brachycephalic": false, "breed_energy": 80},
    "Portuguese Water Dog": {"is_brachycephalic": false, "breed_energy": 80},
    "Pudelpointer": {"is_brachycephalic": false, "breed_energy": 95},
    "Pug": {"is_brachycephalic": true, "breed_energy": 50},
    "Pyrenean Mountain Dog": {"is_brachycephalic": false, "breed_energy": 80},
    "Rat Terrier": {"is_brachycephalic": false, "breed_energy": 80},
    "Redbone Coonhound": {"is_brachycephalic": false, "breed_energy": 80},
    "Rhodesian Ridgeback": {"is_brachycephalic": false, "breed_energy": 95},
    "Rottweiler": {"is_brachycephalic": false, "breed_energy": 80},
    "Saint Bernard": {"is_brachycephalic": false, "breed_energy": 80},
    "Saluki": {"is_brachycephalic": false, "breed_energy": 95},
    "Samoyed": {"is_brachycephalic": false, "breed_energy": 80},
    "Schipperke": {"is_brachycephalic": false, "breed_energy": 80},
    "Scottish Deerhound": {"is_brachycephalic": false, "breed_energy": 80},
    "Scottish Terrier": {"is_brachycephalic": false, "breed_energy": 65},
    "Shetland Sheepdog": {"is_brachycephalic": false, "breed_energy": 80},
    "Shiba Inu": {"is_brachycephalic": false, "breed_energy": 80},
    "Shih Tzu": {"is_brachycephalic": true, "breed_energy": 50},
    "Siberian Husky": {"is_brachycephalic": false, "breed_energy": 95},
    "Silky Terrier": {"is_brachycephalic": false, "breed_energy": 65},
    "Skye Terrier": {"is_brachycephalic": false, "breed_energy": 65},
    "Sloughi": {"is_brachycephalic": false, "breed_energy": 95},
    "Smooth Fox Terrier": {"is_brachycephalic": false, "breed_energy": 80},
    "Soft-Coated Wheaten Terrier": {"is_brachycephalic": false, "breed_energy": 80},
    "Spanish Water Dog": {"is_brachycephalic": false, "breed_energy": 80},
    "Spinone Italiano": {"is_brachycephalic": false, "breed_energy": 80},
    "Staffordshire Bull Terrier": {"is_brachycephalic": true, "breed_energy": 80},
    "Standard Poodle": {"is_brachycephalic": false, "breed_energy": 80},
    "Standard Schnauzer": {"is_brachycephalic": false, "breed_energy": 80},
    "Sussex Spaniel": {"is_brachycephalic": false, "breed_energy": 65},
    "Swedish Vallhund": {"is_brachycephalic": false, "breed_energy": 80},
    "Thai Ridgeback": {"is_brachycephalic": false, "breed_energy": 80},
    "Tibetan Mastiff": {"is_brachycephalic": false, "breed_energy": 80},
    "Toy Fox Terrier": {"is_brachycephalic": false, "breed_energy": 65},
    "Treeing Walker Coonhound": {"is_brachycephalic": false, "breed_energy": 80},
    "Welsh Springer Spaniel": {"is_brachycephalic": false, "breed_energy": 80},
    "Welsh Terrier": {"is_brachycephalic": false, "breed_energy": 65},
    "West Highland White Terrier": {"is_brachycephalic": false, "breed_energy": 65},
    "Whippet": {"is_brachycephalic": false, "breed_energy": 80},
    "Wire Fox Terrier": {"is_brachycephalic": false, "breed_energy": 80},
    "Wirehaired Dachshund": {"is_brachycephalic": false, "breed_energy": 65},
    "Wirehaired Pointing Griffon": {"is_brachycephalic": false, "breed_energy": 80},
    "Xoloitzcuintli": {"is_brachycephalic": false, "breed_energy": 80},
    "Yorkshire Terrier": {"is_brachycephalic": false, "breed_energy": 50}
  };

  static Map<String, dynamic> calculate({
    required String breed,
    required double weightKg,
    required double ageYears,
    required String ownerActivityLevel, // 'low', 'moderate', 'high'
  }) {
    // 1. Determine Age Stage
    String ageStage = 'adult';
    if (ageYears < 1.5) {
      ageStage = 'puppy';
    } else if (ageYears >= 8.0) {
      ageStage = 'senior';
    }

    // 2. Get Breed Data
    final breedInfo = breedData[breed] ?? {"is_brachycephalic": false, "breed_energy": 70};
    bool isBrachy = breedInfo['is_brachycephalic'];
    double breedEnergy = (breedInfo['breed_energy'] as num).toDouble();

    // 3. Determine Size Class & Pace
    String sizeClass = 'medium';
    double sizeMultiplier = 1.0;
    double paceKmh = 4.0;

    if (weightKg < 10.0) {
      sizeClass = 'small';
      sizeMultiplier = constants['size_rules']['small']['multiplier'];
      paceKmh = constants['size_rules']['small']['pace_kmh'];
    } else if (weightKg >= 25.0) {
      sizeClass = 'large';
      sizeMultiplier = constants['size_rules']['large']['multiplier'];
      paceKmh = constants['size_rules']['large']['pace_kmh'];
    } else {
      sizeClass = 'medium';
      sizeMultiplier = constants['size_rules']['medium']['multiplier'];
      paceKmh = constants['size_rules']['medium']['pace_kmh'];
    }

    // 4. Apply Brachycephalic Overrides
    double brachyFactor = 1.0;
    if (isBrachy) {
      brachyFactor = constants['brachycephalic_rules']['factor_multiplier'];
      paceKmh = constants['brachycephalic_rules']['pace_cap_kmh']; // CRITICAL OVERRIDE
    }

    // 5. Get Age & Owner Activity Multipliers
    double ageFactor = constants['age_factors'][ageStage];
    double ownerFactor = constants['owner_activity_multipliers'][ownerActivityLevel] ?? 1.0;

    // 6. Calculate Target Minutes
    // target_minutes = size_multiplier * breed_energy * age_factor * brachycephalic_factor * owner_activity_multiplier
    double targetMinutes = sizeMultiplier * breedEnergy * ageFactor * brachyFactor * ownerFactor;

    // 7. Calculate Target Distance (km)
    // km_target = (target_minutes / 60) * pace_kmh
    double kmTarget = (targetMinutes / 60.0) * paceKmh;

    // 8. Round km_target to nearest 0.5 km
    kmTarget = (kmTarget * 2).round() / 2;

    return {
      'targetMinutes': targetMinutes.round(),
      'kmTarget': kmTarget,
      'paceKmh': paceKmh,
      'sizeClass': sizeClass,
      'ageStage': ageStage,
    };
  }
}
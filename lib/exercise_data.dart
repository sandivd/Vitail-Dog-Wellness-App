class ExerciseData {
  // Map of Breed -> [Puppy (Placeholder), Prime Adult, Early Senior, Mid-Senior, Late Senior]
  // Note: Index 0 is just a placeholder. Puppy time is calculated dynamically below.
  static const Map<String, List<int>> breedMinutes = {
    'Affenpinscher': [60, 90, 68, 45, 23],
    'Afghan Hound': [60, 120, 81, 54, 27],
    'Airedale Terrier': [60, 120, 90, 60, 30],
    'Akita': [60, 120, 72, 48, 24],
    'Alaskan Malamute': [60, 180, 122, 81, 41],
    'American Bulldog': [60, 120, 81, 54, 27],
    'American Eskimo': [60, 120, 90, 60, 30],
    'American Foxhound': [60, 150, 113, 75, 38],
    'Australian Cattle Dog': [60, 150, 113, 75, 38],
    'Australian Shepherd': [60, 150, 101, 68, 34],
    'Australian Terrier': [60, 90, 68, 45, 23],
    'Basenji': [60, 120, 90, 60, 30],
    'Basset Hound': [60, 60, 36, 24, 12],
    'Beagle': [60, 120, 81, 54, 27],
    'Bearded Collie': [60, 120, 90, 60, 30],
    'Bernese Mountain Dog': [60, 90, 54, 36, 18],
    'Bichon Frise': [60, 60, 45, 30, 15],
    'Black Russian Terrier': [60, 120, 81, 54, 27],
    'Bloodhound': [60, 120, 72, 48, 24],
    'Border Collie': [60, 180, 135, 90, 45],
    'Border Terrier': [60, 90, 68, 45, 23],
    'Borzoi': [60, 120, 90, 60, 30],
    'Boston Terrier': [60, 90, 61, 41, 20],
    'Bouvier des Flandres': [60, 120, 81, 54, 27],
    'Boxer': [60, 120, 81, 54, 27],
    'Briard': [60, 120, 90, 60, 30],
    'Brittany': [60, 150, 113, 75, 38],
    'Brussels Griffon': [60, 90, 61, 41, 20],
    'Bull Terrier': [60, 120, 81, 54, 27],
    'Bullmastiff': [60, 90, 54, 36, 18],
    'Cairn Terrier': [60, 90, 68, 45, 23],
    'Canaan Dog': [60, 120, 90, 60, 30],
    'Cane Corso': [60, 120, 81, 54, 27],
    'Cardigan Welsh Corgi': [60, 120, 81, 54, 27],
    'Cavalier King Charles Spaniel': [60, 60, 36, 24, 12],
    'Chesapeake Bay Retriever': [60, 150, 113, 75, 38],
    'Chihuahua': [60, 60, 41, 27, 14],
    'Chinese Crested': [60, 60, 45, 30, 15],
    'Chinese Shar-Pei': [60, 90, 54, 36, 18],
    'Chow Chow': [60, 90, 54, 36, 18],
    'Clumber Spaniel': [60, 90, 61, 41, 20],
    'Cocker Spaniel': [60, 90, 61, 41, 20],
    'Collie': [60, 120, 81, 54, 27],
    'Curly-Coated Retriever': [60, 120, 90, 60, 30],
    'Dachshund': [60, 90, 54, 36, 18],
    'Dalmatian': [60, 150, 90, 60, 30],
    'Dandie Dinmont Terrier': [60, 90, 68, 45, 23],
    'Doberman Pinscher': [60, 150, 101, 68, 34],
    'English Bulldog': [60, 60, 36, 24, 12],
    'English Cocker Spaniel': [60, 90, 61, 41, 20],
    'English Foxhound': [60, 150, 113, 75, 38],
    'English Setter': [60, 120, 81, 54, 27],
    'English Springer Spaniel': [60, 120, 81, 54, 27],
    'English Toy Spaniel': [60, 60, 41, 27, 14],
    'Entlebucher Mountain Dog': [60, 150, 113, 75, 38],
    'Field Spaniel': [60, 120, 90, 60, 30],
    'Finnish Lapphund': [60, 120, 90, 60, 30],
    'Finnish Spitz': [60, 120, 90, 60, 30],
    'Flat-Coated Retriever': [60, 150, 101, 68, 34],
    'French Bulldog': [60, 60, 36, 24, 12],
    'German Pinscher': [60, 120, 90, 60, 30],
    'German Shepherd': [60, 150, 101, 68, 34],
    'German Shorthaired Pointer': [60, 150, 113, 75, 38],
    'German Wirehaired Pointer': [60, 150, 113, 75, 38],
    'Giant Schnauzer': [60, 120, 81, 54, 27],
    'Golden Retriever': [60, 120, 81, 54, 27],
    'Gordon Setter': [60, 120, 81, 54, 27],
    'Great Dane': [60, 120, 72, 48, 24],
    'Great Pyrenees': [60, 90, 61, 41, 20],
    'Greater Swiss Mountain Dog': [60, 120, 81, 54, 27],
    'Greyhound': [60, 120, 90, 60, 30],
    'Harrier': [60, 120, 90, 60, 30],
    'Havanese': [60, 90, 68, 45, 23],
    'Ibizan Hound': [60, 120, 90, 60, 30],
    'Icelandic Sheepdog': [60, 120, 90, 60, 30],
    'Irish Red and White Setter': [60, 150, 101, 68, 34],
    'Irish Setter': [60, 150, 101, 68, 34],
    'Irish Terrier': [60, 90, 68, 45, 23],
    'Irish Water Spaniel': [60, 120, 90, 60, 30],
    'Irish Wolfhound': [60, 120, 72, 48, 24],
    'Italian Greyhound': [60, 90, 61, 41, 20],
    'Japanese Chin': [60, 60, 45, 30, 15],
    'Japanese Spitz': [60, 90, 68, 45, 23],
    'Keeshond': [60, 90, 68, 45, 23],
    'Kerry Blue Terrier': [60, 90, 68, 45, 23],
    'Komondor': [60, 120, 90, 60, 30],
    'Kuvasz': [60, 120, 81, 54, 27],
    'Labrador Retriever': [60, 120, 81, 54, 27],
    'Lakeland Terrier': [60, 90, 68, 45, 23],
    'Leonberger': [60, 120, 72, 48, 24],
    'Lhasa Apso': [60, 60, 45, 30, 15],
    'Lowchen': [60, 90, 68, 45, 23],
    'Maltese': [60, 60, 45, 30, 15],
    'Manchester Terrier': [60, 90, 68, 45, 23],
    'Mastiff': [60, 90, 54, 36, 18],
    'Miniature Pinscher': [60, 90, 68, 45, 23],
    'Miniature Schnauzer': [60, 90, 68, 45, 23],
    'Neapolitan Mastiff': [60, 60, 36, 24, 12],
    'Newfoundland': [60, 120, 81, 54, 27],
    'Norfolk Terrier': [60, 90, 68, 45, 23],
    'Norwegian Buhund': [60, 120, 90, 60, 30],
    'Norwegian Elkhound': [60, 120, 81, 54, 27],
    'Norwegian Lundehund': [60, 120, 72, 48, 24],
    'Old English Sheepdog': [60, 120, 81, 54, 27],
    'Otterhound': [60, 150, 101, 68, 34],
    'Papillon': [60, 60, 45, 30, 15],
    'Pekingese': [60, 60, 36, 24, 12],
    'Pembroke Welsh Corgi': [60, 120, 81, 54, 27],
    'Petit Basset Griffon Vendeen': [60, 120, 81, 54, 27],
    'Pharaoh Hound': [60, 120, 90, 60, 30],
    'Pointer': [60, 150, 101, 68, 34],
    'Pomeranian': [60, 60, 41, 27, 14],
    'Poodle (Miniature)': [60, 90, 68, 45, 23],
    'Poodle (Standard)': [60, 120, 81, 54, 27],
    'Poodle (Toy)': [60, 60, 45, 30, 15],
    'Portuguese Podengo': [60, 120, 90, 60, 30],
    'Portuguese Water Dog': [60, 120, 81, 54, 27],
    'Pudelpointer': [60, 150, 113, 75, 38],
    'Pug': [60, 60, 36, 24, 12],
    'Pyrenean Mountain Dog': [60, 120, 72, 48, 24],
    'Rat Terrier': [60, 120, 81, 54, 27],
    'Redbone Coonhound': [60, 120, 90, 60, 30],
    'Rhodesian Ridgeback': [60, 150, 101, 68, 34],
    'Rottweiler': [60, 120, 72, 48, 24],
    'Saint Bernard': [60, 120, 81, 54, 27],
    'Saluki': [60, 150, 101, 68, 34],
    'Samoyed': [60, 120, 81, 54, 27],
    'Schipperke': [60, 120, 81, 54, 27],
    'Scottish Deerhound': [60, 120, 81, 54, 27],
    'Scottish Terrier': [60, 90, 54, 36, 18],
    'Shetland Sheepdog': [60, 120, 81, 54, 27],
    'Shiba Inu': [60, 120, 81, 54, 27],
    'Shih Tzu': [60, 60, 41, 27, 14],
    'Siberian Husky': [60, 150, 101, 68, 34],
    'Silky Terrier': [60, 90, 68, 45, 23],
    'Skye Terrier': [60, 90, 61, 41, 20],
    'Sloughi': [60, 150, 101, 68, 34],
    'Smooth Fox Terrier': [60, 120, 81, 54, 27],
    'Soft-Coated Wheaten Terrier': [60, 120, 81, 54, 27],
    'Spanish Water Dog': [60, 120, 81, 54, 27],
    'Spinone Italiano': [60, 120, 81, 54, 27],
    'Staffordshire Bull Terrier': [60, 120, 72, 48, 24],
    'Standard Schnauzer': [60, 120, 81, 54, 27],
    'Sussex Spaniel': [60, 90, 61, 41, 20],
    'Swedish Vallhund': [60, 120, 90, 60, 30],
    'Thai Ridgeback': [60, 120, 81, 54, 27],
    'Tibetan Mastiff': [60, 120, 81, 54, 27],
    'Toy Fox Terrier': [60, 90, 68, 45, 23],
    'Treeing Walker Coonhound': [60, 120, 81, 54, 27],
    'Welsh Springer Spaniel': [60, 120, 81, 54, 27],
    'Welsh Terrier': [60, 90, 61, 41, 20],
    'West Highland White Terrier': [60, 90, 61, 41, 20],
    'Whippet': [60, 120, 90, 60, 30],
    'Wire Fox Terrier': [60, 120, 81, 54, 27],
    'Wirehaired Dachshund': [60, 90, 54, 36, 18],
    'Wirehaired Pointing Griffon': [60, 120, 81, 54, 27],
    'Xoloitzcuintli': [60, 120, 81, 54, 27],
    'Yorkshire Terrier': [60, 60, 41, 27, 14],
  };

  // Calculate the index based on the age rules provided
  static int getAgeIndex(double age) {
    // We skip index 0 (Puppy) because it is handled dynamically in getRecommendedMinutes
    if (age < 8.0) return 1; // Prime Adult
    if (age < 10.0) return 2; // Early Senior
    if (age < 12.0) return 3; // Mid-Senior
    return 4; // Late Senior
  }

  static int getRecommendedMinutes(String breed, double ageInYears) {
    // Default fallback if breed is not found
    if (!breedMinutes.containsKey(breed)) return 30; 
    
    List<int> minutesArray = breedMinutes[breed]!;
    int primeAdultMax = minutesArray[1]; // The max exercise this breed should ever do

    // 1. DYNAMIC PUPPY CALCULATION (Under 1.5 years)
    if (ageInYears < 1.5) {
      // Convert years to months
      int ageInMonths = (ageInYears * 12).round();
      
      // 5-minute rule: 5 mins * age in months * 2 walks a day
      int calculatedPuppyMins = ageInMonths * 5 * 2;

      // Cap the puppy minutes so they don't exceed the Prime Adult maximum
      // (e.g., A 14-month-old Pug shouldn't walk 140 mins if its adult max is 60 mins)
      if (calculatedPuppyMins > primeAdultMax) {
        return primeAdultMax;
      }
      return calculatedPuppyMins;
    }

    // 2. ADULT & SENIOR CALCULATION (1.5 years and older)
    int index = getAgeIndex(ageInYears);
    return minutesArray[index];
  }
}
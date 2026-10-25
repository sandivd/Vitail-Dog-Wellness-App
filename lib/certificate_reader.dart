enum CertificateKind { registryCertificate, councilRegistration, unknown }

enum CertificateIssue {
  noMicrochipFound,
  multipleMicrochips,
  testChip,
  notADog,
  unrecognisedDocument,
  dogNameNotFound,
  birthdayMismatch,
  registrationExpired,
  numberMismatch,
  dogNameMismatch,
  breedMismatch,
  numberAlreadyUsed;

  bool get blocksSubmit =>
      this == CertificateIssue.notADog ||
      this == CertificateIssue.testChip ||
      this == CertificateIssue.numberAlreadyUsed;

  String get message => switch (this) {
        CertificateIssue.noMicrochipFound =>
          "We couldn't read a microchip number, so our team will check it by hand.",
        CertificateIssue.multipleMicrochips =>
          'We found more than one possible microchip number, so our team will check it by hand.',
        CertificateIssue.testChip =>
          'This number starts with 999, which is a test chip, not a registered one.',
        CertificateIssue.notADog =>
          "This certificate doesn't look like it's for a dog.",
        CertificateIssue.unrecognisedDocument =>
          "We don't recognise this type of document. Our team will take a look.",
        CertificateIssue.dogNameNotFound =>
          "We couldn't spot your dog's name on it. Double-check it's the right certificate.",
        CertificateIssue.birthdayMismatch =>
          "The date of birth doesn't match the one you entered for your dog.",
        CertificateIssue.registrationExpired =>
          'This council registration has expired. The microchip number still counts, but you may want to renew it.',
        CertificateIssue.numberMismatch =>
          "The number on this certificate doesn't match the microchip number you entered.",
        CertificateIssue.dogNameMismatch =>
          "The dog's name on this certificate doesn't match your dog's name.",
        CertificateIssue.breedMismatch =>
          "The breed on this certificate doesn't match your dog's breed.",
        CertificateIssue.numberAlreadyUsed =>
          'This microchip number is already linked to another dog in Vitail. If you think this is a mistake, contact us.',
      };
}

class CertificateReading {
  const CertificateReading({
    required this.kind,
    required this.issues,
    this.microchipNumber,
    this.isDog,
    this.dateOfBirth,
    this.expiryDate,
    this.animalName,
    this.breed,
  });

  final CertificateKind kind;
  final List<CertificateIssue> issues;
  final String? microchipNumber;
  final bool? isDog;
  final DateTime? dateOfBirth;
  final DateTime? expiryDate;
  final String? animalName;
  final String? breed;

  bool get canSubmit => !issues.any((issue) => issue.blocksSubmit);

  CertificateReading withIssue(CertificateIssue issue) => CertificateReading(
        kind: kind,
        issues: List<CertificateIssue>.unmodifiable(
          issues.contains(issue) ? issues : <CertificateIssue>[...issues, issue],
        ),
        microchipNumber: microchipNumber,
        isDog: isDog,
        dateOfBirth: dateOfBirth,
        expiryDate: expiryDate,
        animalName: animalName,
        breed: breed,
      );
}

const List<String> _registryPhrases = [
  'certificate of identification',
  'central animal records',
  'australasian animal registry',
  'national pet register',
  'petsafe',
  'pet address',
  'microchip registry',
  'animal registry',
];

const List<String> _councilPhrases = [
  'animal registration certificate',
  'registration details',
  'domestic animals act',
  'council',
  'shire of',
  'city of',
];

const List<String> _dogWords = ['dog', 'canine', 'canis'];

const List<String> _otherAnimalWords = [
  'cat',
  'feline',
  'felis',
  'ferret',
  'mustelid',
  'rabbit',
  'horse',
  'equine',
  'bird',
  'avian',
  'guinea pig',
  'rat',
  'mouse',
  'reptile',
];

const Map<String, String> _lookalikes = {
  'O': '0',
  'o': '0',
  'I': '1',
  'l': '1',
  '|': '1',
  'S': '5',
  's': '5',
  'B': '8',
  'Z': '2',
};

const Map<String, int> _months = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

final RegExp _microchipLabel = RegExp(
  r'm?icro\s*-?\s*chip\s*(?:no\b\.?|number\b|num\b\.?|#|id\b)?\s*[:.\-]?',
  caseSensitive: false,
);
final RegExp _speciesLabel = RegExp(
  r'\b(?:animal\s*type|species|type\s*of\s*animal)\b',
  caseSensitive: false,
);
final RegExp _breedLabel =
    RegExp(r'\b(?:primary\s*)?breed\b', caseSensitive: false);
final RegExp _nameLabel = RegExp(
  r"\b(?:(?:animal|pet|dog)(?:'s|s)?\s*name|name\s*of\s*(?:animal|pet|dog))\b",
  caseSensitive: false,
);

const Map<String, String> _breedAliases = {
  'staffy': 'staffordshire',
  'staffie': 'staffordshire',
  'amstaff': 'american staffordshire',
  'lab': 'labrador',
  'gsd': 'german',
  'alsatian': 'german',
  'westie': 'west highland white',
  'sharpei': 'shar pei',
  'frenchie': 'french',
  'husky': 'siberian',
};

const Set<String> _genericBreedWords = {
  'dog',
  'dogs',
  'breed',
  'cross',
  'crossbreed',
  'x',
  'mix',
  'mixed',
  'terrier',
  'retriever',
  'spaniel',
  'hound',
  'shepherd',
  'setter',
  'pointer',
  'sheepdog',
  'mountain',
  'miniature',
  'mini',
  'standard',
  'toy',
  'the',
  'and',
  'des',
  'of',
  'coated',
  'haired',
  'wirehaired',
  'smooth',
  'wire',
  'long',
  'short',
  'colour',
  'color',
  'sex',
  'male',
  'female',
};
final RegExp _birthLabel = RegExp(
  r'\b(?:date\s*of\s*birth|d\.?o\.?b)\b\.?',
  caseSensitive: false,
);
final RegExp _expiryLabel = RegExp(
  r'\b(?:expiry(?:\s*date)?|expires|valid\s*until)\b',
  caseSensitive: false,
);
final RegExp _digitGroups = RegExp(r'(?<!\d)\d{3,}(?: \d{3,})*(?!\d)');

CertificateReading readCertificateText(
  String text, {
  String? dogName,
  DateTime? dogBirthday,
  String? dogBreed,
  String? expectedNumber,
  DateTime? today,
}) {
  final List<String> lines = text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  final String flat = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  final List<CertificateIssue> issues = <CertificateIssue>[];

  final Set<String> labelled = _labelledNumbers(lines);
  final Set<String> candidates =
      labelled.isNotEmpty ? labelled : _unlabelledNumbers(lines);
  String? microchip;
  if (candidates.length == 1) {
    microchip = candidates.first;
    if (microchip.startsWith('999')) issues.add(CertificateIssue.testChip);
  } else if (candidates.isEmpty) {
    issues.add(CertificateIssue.noMicrochipFound);
  } else {
    issues.add(CertificateIssue.multipleMicrochips);
  }
  final String expected = expectedNumber?.replaceAll(RegExp(r'\s'), '') ?? '';
  if (microchip != null &&
      RegExp(r'^\d{15}$').hasMatch(expected) &&
      microchip != expected) {
    issues.add(CertificateIssue.numberMismatch);
  }

  final CertificateKind kind = _kindOf(flat);
  if (kind == CertificateKind.unknown) {
    issues.add(CertificateIssue.unrecognisedDocument);
  }

  final bool? isDog = _isDog(_valueAfter(lines, _speciesLabel)) ??
      _isDog(_valueAfter(lines, _breedLabel));
  if (isDog == false) issues.add(CertificateIssue.notADog);

  final DateTime? birth = _parseDate(_valueAfter(lines, _birthLabel));
  if (dogBirthday != null &&
      birth != null &&
      !_sameDay(birth, dogBirthday) &&
      !(birth.day <= 12 &&
          _sameDay(DateTime(birth.year, birth.day, birth.month), dogBirthday))) {
    issues.add(CertificateIssue.birthdayMismatch);
  }

  final String? certBreed = _valueAfter(lines, _breedLabel);
  if (dogBreed != null && certBreed != null && _breedsDiffer(certBreed, dogBreed)) {
    issues.add(CertificateIssue.breedMismatch);
  }

  final DateTime? expiry = _parseDate(_valueAfter(lines, _expiryLabel));
  final DateTime now = today ?? DateTime.now();
  if (kind == CertificateKind.councilRegistration &&
      expiry != null &&
      expiry.isBefore(DateTime(now.year, now.month, now.day))) {
    issues.add(CertificateIssue.registrationExpired);
  }

  final String? certName = _valueAfter(lines, _nameLabel);
  final String name = _normalise(dogName ?? '');
  if (name.isNotEmpty) {
    if (certName != null) {
      if (!' ${_normalise(certName)} '.contains(' $name ')) {
        issues.add(CertificateIssue.dogNameMismatch);
      }
    } else if (!' ${_normalise(text)} '.contains(' $name ')) {
      issues.add(CertificateIssue.dogNameNotFound);
    }
  }

  return CertificateReading(
    kind: kind,
    issues: List<CertificateIssue>.unmodifiable(issues),
    microchipNumber: microchip,
    isDog: isDog,
    dateOfBirth: birth,
    expiryDate: expiry,
    animalName: certName,
    breed: certBreed,
  );
}

String _normalise(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim();

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

Set<String> _breedWords(String value) {
  final Set<String> words = <String>{};
  for (final String word in _normalise(value).split(' ')) {
    if (word.isEmpty) continue;
    final String expanded = _breedAliases[word] ?? word;
    for (final String part in expanded.split(' ')) {
      if (!_genericBreedWords.contains(part)) words.add(part);
    }
  }
  return words;
}

bool _breedsDiffer(String certificateBreed, String appBreed) {
  final Set<String> certificate = _breedWords(certificateBreed);
  final Set<String> app = _breedWords(appBreed);
  if (certificate.isEmpty || app.isEmpty) return false;
  return certificate.intersection(app).isEmpty;
}

Set<String> _labelledNumbers(List<String> lines) {
  final Set<String> found = <String>{};
  for (int i = 0; i < lines.length; i++) {
    for (final RegExpMatch match in _microchipLabel.allMatches(lines[i])) {
      final String? sameLine = _numberStartingIn(lines[i].substring(match.end));
      final String? number = sameLine ??
          (i + 1 < lines.length ? _numberStartingIn(lines[i + 1]) : null);
      if (number != null) found.add(number);
    }
  }
  return found;
}

Set<String> _unlabelledNumbers(List<String> lines) {
  final Set<String> found = <String>{};
  for (final String line in lines) {
    for (final RegExpMatch match in _digitGroups.allMatches(line)) {
      final String digits = match.group(0)!.replaceAll(' ', '');
      if (digits.length == 15) found.add(digits);
    }
  }
  return found;
}

String? _numberStartingIn(String text) {
  final StringBuffer number = StringBuffer();
  for (final String raw in text.trim().split(RegExp(r'\s+'))) {
    final String token =
        raw.replaceAll(RegExp(r'^[^0-9A-Za-z|]+|[^0-9A-Za-z|]+$'), '');
    if (token.isEmpty) {
      if (number.isEmpty) continue;
      break;
    }
    final String? digits = _tokenDigits(token);
    if (digits == null) break;
    number.write(digits);
    if (number.length >= 15) break;
  }
  return number.length == 15 ? number.toString() : null;
}

String? _tokenDigits(String token) {
  final StringBuffer out = StringBuffer();
  int realDigits = 0;
  for (final int unit in token.codeUnits) {
    final String ch = String.fromCharCode(unit);
    if (unit >= 48 && unit <= 57) {
      out.write(ch);
      realDigits++;
    } else if (_lookalikes.containsKey(ch)) {
      out.write(_lookalikes[ch]);
    } else if (ch != '-') {
      return null;
    }
  }
  return realDigits == 0 ? null : out.toString();
}

CertificateKind _kindOf(String flat) {
  if (_registryPhrases.any((phrase) => flat.contains(phrase))) {
    return CertificateKind.registryCertificate;
  }
  if (_councilPhrases.any((phrase) => flat.contains(phrase))) {
    return CertificateKind.councilRegistration;
  }
  return CertificateKind.unknown;
}

String? _valueAfter(List<String> lines, RegExp label) {
  for (int i = 0; i < lines.length; i++) {
    final RegExpMatch? match = label.firstMatch(lines[i]);
    if (match == null) continue;
    final String rest =
        lines[i].substring(match.end).replaceFirst(RegExp(r'^[\s:.\-]+'), '');
    if (rest.isNotEmpty) return rest;
    if (i + 1 < lines.length) return lines[i + 1];
  }
  return null;
}

bool? _isDog(String? value) {
  if (value == null) return null;
  final String lower = value.toLowerCase();
  bool has(String word) =>
      RegExp('\\b${RegExp.escape(word)}\\b').hasMatch(lower);
  if (_dogWords.any(has)) return true;
  if (_otherAnimalWords.any(has)) return false;
  return null;
}

DateTime? _parseDate(String? value) {
  if (value == null) return null;
  final RegExpMatch? numeric =
      RegExp(r'(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})').firstMatch(value);
  if (numeric != null) {
    return _date(
      int.parse(numeric.group(3)!),
      int.parse(numeric.group(2)!),
      int.parse(numeric.group(1)!),
    );
  }
  final RegExpMatch? named = RegExp(
    r'(\d{1,2})[\s/.\-]*([A-Za-z]{3})[A-Za-z]*[\s/.\-,]*(\d{4})',
  ).firstMatch(value);
  if (named != null) {
    final int? month = _months[named.group(2)!.toLowerCase()];
    if (month == null) return null;
    return _date(
      int.parse(named.group(3)!),
      month,
      int.parse(named.group(1)!),
    );
  }
  return null;
}

DateTime? _date(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final DateTime date = DateTime(year, month, day);
  return date.month == month ? date : null;
}
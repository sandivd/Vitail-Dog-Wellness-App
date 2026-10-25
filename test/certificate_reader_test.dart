import 'package:flutter_test/flutter_test.dart';
import 'package:vitail/certificate_layout.dart';
import 'package:vitail/certificate_reader.dart';

const String registryText = '''
CERTIFICATE OF IDENTIFICATION
Central Animal Records
Animal Name: Luna
Species: Canine
Breed: Labrador Retriever
Date of Birth: 01/02/2025
Microchip No.: 900 123 456 789 012
''';

const String ferretText = '''
CERTIFICATE OF IDENTIFICATION
Central Animal Records
Animal Name: Luna
Species: Mustelid
Microchip No.: 900 123 456 789 012
''';

const String councilText = '''
City of Port Phillip
Animal Registration Certificate
Animal Name: Luna
Animal Type: Dog
Microchip No: 900123456789012
Expiry Date: 09-Apr-2026
''';

final DateTime today = DateTime(2026, 10, 25);

const List<List<String>> councilRows = <List<String>>[
  <String>['Animal ID', '500001'],
  <String>['Animal Type', 'Dog'],
  <String>['Animal Name', 'Der'],
  <String>['Classification', '1. Domestic Standard Dog'],
  <String>['Primary Breed', 'Airedale Terrier'],
  <String>['Colour', 'Black and Tan'],
  <String>['Microchip No.', '900012345678901'],
  <String>['Tag Number', '200001'],
  <String>['Date of Birth', '06-Oct-2026'],
];

const String councilHeader =
    'Animal Registration Certificate\nCity of Testhaven\nREGISTRATION DETAILS\n';

void main() {
  test('reads a matching registry certificate with no issues', () {
    final CertificateReading reading = readCertificateText(
      registryText,
      dogName: 'Luna',
      dogBirthday: DateTime(2025, 2, 1),
      dogBreed: 'Labrador Retriever',
      expectedNumber: '900123456789012',
      today: today,
    );
    expect(reading.microchipNumber, '900123456789012');
    expect(reading.kind, CertificateKind.registryCertificate);
    expect(reading.isDog, isTrue);
    expect(reading.dateOfBirth, DateTime(2025, 2, 1));
    expect(reading.animalName, 'Luna');
    expect(reading.breed, 'Labrador Retriever');
    expect(reading.issues, isEmpty);
    expect(reading.canSubmit, isTrue);
  });

  test('warns when the certificate number differs from the entered number', () {
    final CertificateReading reading = readCertificateText(
      registryText,
      dogName: 'Luna',
      expectedNumber: '900123456789099',
      today: today,
    );
    expect(reading.issues, contains(CertificateIssue.numberMismatch));
    expect(reading.canSubmit, isTrue);
  });

  test('skips the number comparison when no valid number was entered', () {
    for (final String? entered in <String?>[null, '', '12345']) {
      final CertificateReading reading = readCertificateText(
        registryText,
        expectedNumber: entered,
        today: today,
      );
      expect(reading.issues, isNot(contains(CertificateIssue.numberMismatch)));
    }
  });

  test('blocks a certificate for a ferret', () {
    final CertificateReading reading = readCertificateText(
      ferretText,
      today: today,
    );
    expect(reading.isDog, isFalse);
    expect(reading.issues, contains(CertificateIssue.notADog));
    expect(reading.canSubmit, isFalse);
  });

  test('blocks a 999 test chip', () {
    final CertificateReading reading = readCertificateText(
      registryText.replaceFirst('900 123', '999 123'),
      today: today,
    );
    expect(reading.issues, contains(CertificateIssue.testChip));
    expect(reading.canSubmit, isFalse);
  });

  test('warns about an expired council registration but allows submit', () {
    final CertificateReading reading = readCertificateText(
      councilText,
      dogName: 'Luna',
      today: today,
    );
    expect(reading.kind, CertificateKind.councilRegistration);
    expect(reading.expiryDate, DateTime(2026, 4, 9));
    expect(reading.issues, <CertificateIssue>[
      CertificateIssue.registrationExpired,
    ]);
    expect(reading.canSubmit, isTrue);
  });

  test('flags a different dog name and birthday', () {
    final CertificateReading reading = readCertificateText(
      registryText,
      dogName: 'Dora',
      dogBirthday: DateTime(2023, 6, 1),
      today: today,
    );
    expect(reading.issues, contains(CertificateIssue.dogNameMismatch));
    expect(reading.issues, contains(CertificateIssue.birthdayMismatch));
    expect(reading.canSubmit, isTrue);
  });

  test('flags a birthday that is off by a single day', () {
    final CertificateReading reading = readCertificateText(
      registryText,
      dogBirthday: DateTime(2025, 2, 2),
      today: today,
    );
    expect(reading.issues, contains(CertificateIssue.birthdayMismatch));
  });

  test('accepts a birthday written month-first', () {
    final CertificateReading reading = readCertificateText(
      registryText,
      dogBirthday: DateTime(2025, 1, 2),
      today: today,
    );
    expect(reading.issues, isNot(contains(CertificateIssue.birthdayMismatch)));
  });

  test('flags a different breed', () {
    final CertificateReading reading = readCertificateText(
      registryText,
      dogBreed: 'Golden Retriever',
      today: today,
    );
    expect(reading.issues, contains(CertificateIssue.breedMismatch));
    expect(reading.canSubmit, isTrue);
  });

  test('matches cross breeds and common short names', () {
    final Map<String, String> pairs = <String, String>{
      'Labrador X': 'Labrador Retriever',
      'Staffy Cross': 'Staffordshire Bull Terrier',
      'Toy Poodle': 'Poodle (Toy)',
      'Mixed Breed': 'Beagle',
    };
    pairs.forEach((String onCertificate, String inApp) {
      final CertificateReading reading = readCertificateText(
        registryText.replaceFirst('Labrador Retriever', onCertificate),
        dogBreed: inApp,
        today: today,
      );
      expect(
        reading.issues,
        isNot(contains(CertificateIssue.breedMismatch)),
        reason: '$onCertificate vs $inApp',
      );
    });
  });

  test('searches the whole text when there is no name label', () {
    final String unlabelled = registryText.replaceFirst(
      'Animal Name: Luna',
      'Pet: Luna',
    );
    expect(
      readCertificateText(unlabelled, dogName: 'Luna', today: today).issues,
      isNot(contains(CertificateIssue.dogNameNotFound)),
    );
    expect(
      readCertificateText(unlabelled, dogName: 'Dora', today: today).issues,
      contains(CertificateIssue.dogNameNotFound),
    );
  });

  test('a number already used by another dog blocks submit', () {
    final CertificateReading reading = readCertificateText(
      registryText,
      today: today,
    ).withIssue(CertificateIssue.numberAlreadyUsed);
    expect(reading.issues, contains(CertificateIssue.numberAlreadyUsed));
    expect(reading.canSubmit, isFalse);
  });

  test('falls back to manual review when no number can be read', () {
    final CertificateReading reading = readCertificateText(
      registryText.replaceFirst('900 123 456 789 012', '956 XXX XXX XXX 582'),
      today: today,
    );
    expect(reading.microchipNumber, isNull);
    expect(reading.issues, contains(CertificateIssue.noMicrochipFound));
    expect(reading.canSubmit, isTrue);
  });

  test('column layout read out of order gives no false name or breed warnings', () {
    final String columns = councilHeader +
        councilRows.map((List<String> row) => row[0]).join('\n') +
        '\n' +
        councilRows.map((List<String> row) => row[1]).join('\n');
    final CertificateReading reading = readCertificateText(
      columns,
      dogName: 'Der',
      dogBreed: 'Airedale Terrier',
      dogBirthday: DateTime(2026, 10, 6),
      today: today,
    );
    expect(reading.microchipNumber, '900012345678901');
    expect(reading.animalName, isNull);
    expect(reading.breed, isNull);
    expect(reading.issues, isEmpty);
  });

  test('joinTextRows puts each label next to its value', () {
    final List<OcrLine> lines = <OcrLine>[
      for (int i = 0; i < councilRows.length; i++)
        OcrLine(councilRows[i][0], 40, 300.0 + i * 32, 160, 318.0 + i * 32),
      for (int i = 0; i < councilRows.length; i++)
        OcrLine(councilRows[i][1], 200, 304.0 + i * 32, 420, 322.0 + i * 32),
      const OcrLine('COPP Certificate Of Registration', 760, 20, 776, 400),
    ];
    final String joined = joinTextRows(lines);
    expect(joined.split('\n'), contains('Animal Name   Der'));
    expect(joined, isNot(contains('COPP')));

    final CertificateReading reading = readCertificateText(
      councilHeader + joined,
      dogName: 'Der',
      dogBreed: 'Airedale Terrier',
      dogBirthday: DateTime(2026, 10, 6),
      today: today,
    );
    expect(reading.animalName, 'Der');
    expect(reading.breed, 'Airedale Terrier');
    expect(reading.dateOfBirth, DateTime(2026, 10, 6));
    expect(reading.isDog, isTrue);
    expect(reading.issues, isEmpty);
  });

  test('joinTextRows keeps paragraph lines separate', () {
    final String joined = joinTextRows(const <OcrLine>[
      OcrLine('Please check we have recorded', 40, 600, 500, 618),
      OcrLine('your pet details correctly.', 40, 622, 480, 640),
    ]);
    expect(joined.split('\n'), hasLength(2));
  });
}

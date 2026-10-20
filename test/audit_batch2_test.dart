// Batch 2 audit fixes (2026-10-19): Smart Care symptom relevance
// and provider phone fields defaulting to "not provided".
import 'package:flutter_test/flutter_test.dart';
import 'package:remedoo_app/models.dart';
import 'package:remedoo_app/screens/care_match_screen.dart';

void main() {
  group('relevantSpecialtiesForSymptom', () {
    test('chest symptoms point to Cardiology', () {
      expect(relevantSpecialtiesForSymptom('Sharp chest discomfort'),
          contains('Cardiology'));
    });

    test('skin rash points to Dermatology', () {
      expect(relevantSpecialtiesForSymptom('itchy skin rash on arms'),
          contains('Dermatology'));
    });

    test('fever and body ache point to a General Physician', () {
      expect(relevantSpecialtiesForSymptom('Fever and body ache'),
          contains('General Physician'));
    });

    test('a specialty named outright is relevant', () {
      expect(relevantSpecialtiesForSymptom('need a cardiology opinion'),
          contains('Cardiology'));
    });

    test('empty or unrelated text yields no specialties', () {
      expect(relevantSpecialtiesForSymptom(''), isEmpty);
      expect(relevantSpecialtiesForSymptom('just browsing'), isEmpty);
    });
  });

  group('provider phone fields', () {
    test('default to empty (not provided) when not supplied', () {
      const h = Hospital(
        id: 'h1',
        name: 'H',
        location: 'L',
        government: false,
        hasIcu: false,
        beds: 10,
        rating: 4,
        reviews: 1,
        waitMin: 5,
        distanceKm: 1,
        verified: false,
      );
      const l = Lab(
        id: 'l1',
        name: 'L',
        location: 'L',
        testCount: 1,
        offers: 0,
        turnaround: '24h',
        rating: 4,
        reviews: 1,
        nabl: false,
        verified: false,
        distanceKm: 1,
      );
      const p = Pharmacy(
        id: 'p1',
        name: 'P',
        location: 'L',
        rating: 4,
        reviews: 1,
        deliveryTime: '30 min',
        itemCount: 10,
        offers: 0,
        verified: false,
        distanceKm: 1,
      );
      expect(h.phone, isEmpty);
      expect(h.emergencyContact, isEmpty);
      expect(l.phone, isEmpty);
      expect(p.phone, isEmpty);
    });
  });
}

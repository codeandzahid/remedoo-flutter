import '../models.dart';

/// Mock data for the Remedoo demo. Everything here is fictional.
/// DATA-LAYER SEAM: each public getter below (doctors, hospitals, labs,
/// pharmacies, medicines...) is the single place the UI reads from. To wire
/// Supabase later, replace these getters with async repository calls and make
/// AppState await them — no screen code needs to change.

const List<String> specialties = [
  'General Physician',
  'Cardiology',
  'Dermatology',
  'Neurology',
  'Orthopedics',
  'Pediatrics',
  'Gynecology',
  'ENT',
  'Ophthalmology',
  'Psychiatry',
  'Dentistry',
  'Gastroenterology',
  'Urology',
  'Nephrology',
  'Pulmonology',
  'Endocrinology',
];

const List<String> localities = [
  'Lal Chowk, Srinagar',
  'Dalgate, Srinagar',
  'Bemina, Srinagar',
  'Hyderpora, Srinagar',
  'Rajbagh, Srinagar',
  'Jawahar Nagar, Srinagar',
  'Nowshera, Srinagar',
  'Hazratbal, Srinagar',
  'Soura, Srinagar',
  'Chanapora, Srinagar',
  'Gandhi Nagar, Jammu',
  'Trikuta Nagar, Jammu',
  'Channi Himmat, Jammu',
  'Bantalab, Jammu',
  'Janipur, Jammu',
  'Talab Tillo, Jammu',
  'Anantnag',
  'Baramulla',
];

const List<String> _firstNames = [
  'Aarav', 'Ananya', 'Vihaan', 'Meera', 'Arjun', 'Priya', 'Rohan', 'Kavya',
  'Kabir', 'Sneha', 'Aditya', 'Divya', 'Ishaan', 'Pooja', 'Vikram', 'Ritu',
  'Rajesh', 'Sana', 'Amit', 'Aisha', 'Karan', 'Zoya', 'Imran', 'Hina',
  'Bilal', 'Saima', 'Farhan', 'Insha', 'Tariq', 'Rabia', 'Owais', 'Nusrat',
];

const List<String> _lastNames = [
  'Sharma', 'Iyer', 'Nair', 'Malhotra', 'Reddy', 'Gupta', 'Khan', 'Ahmed',
  'Dar', 'Bhat', 'Wani', 'Lone', 'Mir', 'Shah', 'Qureshi', 'Singh',
  'Kumar', 'Joshi', 'Rao', 'Menon', 'Khuroo', 'Andrabi', 'Mattoo', 'Raina',
];

const List<String> _hospitalNames = [
  'Noora Hospital', 'Shifa Medical Centre', 'Jhelum Valley Hospital',
  'Kashmir Care Hospital', 'Dawn Healthcare', 'GreenLand Hospital',
  'CityCare Multispecialty', 'Safa Marwa Clinic', 'DalGate Nursing Home',
  'Bemina Health Centre', 'Chanapora Medical', 'Rajbagh Hospital',
  'Hyderpora Care', 'Nowgam Polyclinic', 'Soura Medical Institute',
  'Hazratbal Hospital', 'Nishat Health Hub', 'Shalimar Medical Centre',
  'Gandhi Nagar Hospital', 'Trikuta Nursing Home', 'Channi Care Hospital',
  'Bantalab Medical', 'Janipur Health Centre', 'Talab Tillo Hospital',
  'RS Pura Clinic', 'Bari Brahmana Hospital', 'Katra Road Medical',
  'Rehari Health Hub', 'Bakshi Nagar Hospital', 'Amphalla Medical Centre',
  'New Plot Clinic', 'Domana Health Care', 'Akhnoor Road Hospital',
  'Marh Medical Centre', 'Khour Health Hub', 'Sunderbani Clinic',
  'Nowshera Medical', 'Rajouri Road Hospital', 'Poonch Care Centre',
  'Doda Valley Hospital', 'Kishtwar Medical', 'Bhaderwah Health Centre',
  'Ramban Clinic', 'Banihal Medical', 'Qazigund Hospital',
  'Anantnag Care', 'Bijbehara Medical', 'Pulwama Health Centre',
];

const List<String> _labNames = [
  'AccuPath Labs', 'Kashmir Diagnostics', 'MediScan Labs',
  'TrueCare Pathology', 'LifeLine Labs', 'HealthFirst Diagnostics',
  'Valley Labs', 'GreenCross Labs', 'CityPath Labs', 'Nova Diagnostics',
  'PrimeScan Labs', 'CarePath Labs', 'MediTest Diagnostics', 'SwiftLabs',
  'TrustCare Labs', 'Orange Health Labs', 'BlueBell Diagnostics',
  'StarPath Labs', 'RapidTest Labs', 'FamilyCare Labs', 'MaxWell Diagnostics',
  'ClearView Labs', 'SureTest Labs', 'VitalPath Labs', 'GenX Diagnostics',
  'MediCore Labs', 'PathCare Labs', 'LabPoint Diagnostics', 'CheckUp Labs',
  'Diagnostic Hub', 'Wellness Labs',
];

const List<String> _pharmacyNames = [
  'Haemath Pharmacy', 'Arsh Medicate', 'CityMed Pharmacy',
  'HealthPlus Stores', 'MediKart', 'Wellness Pharmacy', 'LifeCare Pharmacy',
  'GreenCross Pharmacy', 'CarePoint Pharmacy', 'MediServe Stores',
  'PharmaHub', 'DailyDose Pharmacy', 'CureWell Stores', 'VitaPlus Pharmacy',
  'MediHome Stores', 'QuickMeds Pharmacy', 'FamilyCare Pharmacy',
  'TrustMeds Stores', 'MediBox Pharmacy', 'HealWell Pharmacy',
  'PrimeMeds Stores', 'CareMeds Pharmacy', 'SafeDose Stores',
  'MediNest Pharmacy', 'PureCare Stores', 'NovaMeds Pharmacy',
  'GoodHealth Stores', 'MediTrust Pharmacy', 'SwiftMeds Stores',
  'Valley Pharmacy', 'Downtown Pharmacy',
];

const List<String> _aboutTemplates = [
  'Known for a calm, patient-first approach and clear explanations of every treatment option.',
  'Believes in preventive care and spends extra time on lifestyle guidance with every patient.',
  'Combines modern diagnostics with a gentle bedside manner that patients consistently praise.',
  'Focuses on accurate diagnosis first, and is known for honest, no-rush consultations.',
];

final List<Doctor> doctors = List.generate(41, (i) {
      final first = _firstNames[i % _firstNames.length];
      final last = _lastNames[(i * 7 + 3) % _lastNames.length];
      return Doctor(
        id: 'd$i',
        name: 'Dr. $first $last',
        specialty: specialties[i % specialties.length],
        hospital: _hospitalNames[i % _hospitalNames.length],
        fee: (300 + ((i * 137) % 11) * 100).toDouble(),
        rating: double.parse(
            (3.9 + ((i * 53) % 11) / 10).toStringAsFixed(1)),
        reviews: 180 + (i * 173) % 2200,
        expYears: 4 + (i * 7) % 26,
        waitMin: 10 + (i * 11) % 45,
        distanceKm: 0.5 + ((i * 13) % 28) / 2,
        verified: i % 4 != 3,
        about: _aboutTemplates[i % _aboutTemplates.length],
      );
    });

final List<Hospital> hospitals = List.generate(48, (i) {
      return Hospital(
        id: 'h$i',
        name: _hospitalNames[i],
        location: localities[i % localities.length],
        government: i % 3 == 0,
        hasIcu: i % 4 != 2,
        beds: 50 + (i * 37) % 450,
        rating: double.parse(
            (3.8 + ((i * 41) % 12) / 10).toStringAsFixed(1)),
        reviews: 320 + (i * 211) % 3800,
        waitMin: 5 + (i * 9) % 50,
        distanceKm: 0.8 + ((i * 17) % 30) / 2,
        verified: i % 5 != 4,
      );
    });

final List<Lab> labs = List.generate(31, (i) {
      return Lab(
        id: 'l$i',
        name: _labNames[i],
        location: localities[(i * 3) % localities.length],
        testCount: 80 + (i * 53) % 420,
        offers: 1 + (i * 7) % 9,
        turnaround: ['4-6 hrs', '6-12 hrs', '12-24 hrs'][i % 3],
        rating: double.parse(
            (3.9 + ((i * 47) % 11) / 10).toStringAsFixed(1)),
        reviews: 150 + (i * 97) % 1600,
        nabl: i % 3 != 2,
        verified: i % 4 != 3,
        distanceKm: 0.6 + ((i * 11) % 26) / 2,
      );
    });

final List<Pharmacy> pharmacies = List.generate(31, (i) {
      return Pharmacy(
        id: 'p$i',
        name: _pharmacyNames[i],
        location: localities[(i * 5 + 1) % localities.length],
        rating: double.parse(
            (3.9 + ((i * 43) % 11) / 10).toStringAsFixed(1)),
        reviews: 210 + (i * 131) % 2400,
        deliveryTime: ['20-30 min', '25-35 min', '30-45 min'][i % 3],
        itemCount: 40 + (i * 29) % 160,
        offers: 1 + (i * 5) % 8,
        verified: i % 4 != 3,
        distanceKm: 0.4 + ((i * 7) % 20) / 2,
      );
    });

const List<Map<String, Object>> _medicineRows = [
  {'n': 'Paracetamol 650mg', 'pack': '15 tablets', 'b': 'PyraCare', 'p': 45.0, 'm': 60.0, 'rx': false, 'c': 'Pain Relief'},
  {'n': 'Cetirizine 10mg', 'pack': '10 tablets', 'b': 'AllerFree', 'p': 38.0, 'm': 52.0, 'rx': false, 'c': 'Allergy'},
  {'n': 'Azithromycin 500mg', 'pack': '3 tablets', 'b': 'ZithroCure', 'p': 89.0, 'm': 110.0, 'rx': true, 'c': 'Antibiotics'},
  {'n': 'Amoxicillin 500mg', 'pack': '10 capsules', 'b': 'MoxiCure', 'p': 95.0, 'm': 120.0, 'rx': true, 'c': 'Antibiotics'},
  {'n': 'Omeprazole 20mg', 'pack': '15 capsules', 'b': 'Acifree', 'p': 65.0, 'm': 85.0, 'rx': false, 'c': 'Gastro'},
  {'n': 'Metformin 500mg', 'pack': '30 tablets', 'b': 'Gluconorm', 'p': 55.0, 'm': 75.0, 'rx': true, 'c': 'Diabetes'},
  {'n': 'Atorvastatin 10mg', 'pack': '30 tablets', 'b': 'Lipicure', 'p': 120.0, 'm': 150.0, 'rx': true, 'c': 'Cardiology'},
  {'n': 'Amlodipine 5mg', 'pack': '30 tablets', 'b': 'PresSure', 'p': 70.0, 'm': 95.0, 'rx': true, 'c': 'Cardiology'},
  {'n': 'Salbutamol Inhaler 100mcg', 'pack': '1 inhaler', 'b': 'BreathEasy', 'p': 185.0, 'm': 240.0, 'rx': true, 'c': 'Respiratory'},
  {'n': 'Montelukast 10mg', 'pack': '15 tablets', 'b': 'AirClear', 'p': 140.0, 'm': 180.0, 'rx': true, 'c': 'Respiratory'},
  {'n': 'Vitamin C 500mg', 'pack': '20 chewable', 'b': 'VitaBoost', 'p': 99.0, 'm': 140.0, 'rx': false, 'c': 'Supplements'},
  {'n': 'Multivitamin Daily', 'pack': '30 tablets', 'b': 'NutriMax', 'p': 249.0, 'm': 320.0, 'rx': false, 'c': 'Supplements'},
  {'n': 'Ibuprofen 400mg', 'pack': '15 tablets', 'b': 'PainRelief', 'p': 55.0, 'm': 72.0, 'rx': false, 'c': 'Pain Relief'},
  {'n': 'Diclofenac Gel 30g', 'pack': '30g tube', 'b': 'FlexiGel', 'p': 85.0, 'm': 110.0, 'rx': false, 'c': 'Pain Relief'},
  {'n': 'Antiseptic Liquid 100ml', 'pack': '100 ml', 'b': 'SafeGuard', 'p': 99.0, 'm': 120.0, 'rx': false, 'c': 'First Aid'},
  {'n': 'Bandage Roll 5cm', 'pack': '1 roll', 'b': 'HealWrap', 'p': 35.0, 'm': 45.0, 'rx': false, 'c': 'First Aid'},
  {'n': 'Digital Thermometer', 'pack': '1 unit', 'b': 'TempCheck', 'p': 199.0, 'm': 299.0, 'rx': false, 'c': 'Devices'},
  {'n': 'ORS Powder', 'pack': '21.8g sachet', 'b': 'ReHydrate', 'p': 25.0, 'm': 32.0, 'rx': false, 'c': 'Rehydration'},
  {'n': 'Cough Relief Syrup 100ml', 'pack': '100 ml', 'b': 'TusQlear', 'p': 95.0, 'm': 125.0, 'rx': false, 'c': 'Cold & Cough'},
  {'n': 'Antifungal Cream 30g', 'pack': '30 g', 'b': 'FungiGone', 'p': 110.0, 'm': 145.0, 'rx': false, 'c': 'Skin'},
  {'n': 'Thyroxine 50mcg', 'pack': '30 tablets', 'b': 'ThyroNorm', 'p': 78.0, 'm': 105.0, 'rx': true, 'c': 'Thyroid'},
  {'n': 'Pantoprazole 40mg', 'pack': '15 tablets', 'b': 'Acibloc', 'p': 92.0, 'm': 118.0, 'rx': true, 'c': 'Gastro'},
  {'n': 'Losartan 50mg', 'pack': '30 tablets', 'b': 'CardioSafe', 'p': 105.0, 'm': 140.0, 'rx': true, 'c': 'Cardiology'},
  {'n': 'Calcium + D3', 'pack': '30 tablets', 'b': 'BoneStrong', 'p': 175.0, 'm': 220.0, 'rx': false, 'c': 'Supplements'},
];

final List<Medicine> medicines = List.generate(_medicineRows.length, (i) {
      final r = _medicineRows[i];
      return Medicine(
        id: 'm$i',
        pharmacyId: 'p${i % 31}',
        name: r['n'] as String,
        pack: r['pack'] as String,
        brand: r['b'] as String,
        price: r['p'] as double,
        mrp: r['m'] as double,
        rxRequired: r['rx'] as bool,
        category: r['c'] as String,
      );
    });

/// Deterministic catalogue slice per pharmacy so every vendor screen
/// shows a realistic, stable set of medicines.
List<Medicine> medicinesForPharmacy(String pharmacyId) {
  final all = medicines;
  final seed = pharmacyId.hashCode.abs();
  return all
      .where((m) => (m.id.hashCode + seed) % 31 < 9)
      .toList();
}

Doctor doctorById(String id) => doctors.firstWhere((d) => d.id == id);
Hospital hospitalById(String id) => hospitals.firstWhere((h) => h.id == id);
Lab labById(String id) => labs.firstWhere((l) => l.id == id);
Pharmacy pharmacyById(String id) => pharmacies.firstWhere((p) => p.id == id);

const List<String> pharmacyCategories = [
  'All',
  'Allergy',
  'Cardiology',
  'Diabetes',
  'Gastro',
  'Respiratory',
  'Thyroid',
];

const List<String> symptomChips = [
  'Fever and body ache',
  'Chest discomfort',
  'Persistent cough',
  'Stomach pain',
  'Skin rash',
  'Headache and dizziness',
];

final List<LabTest> labTests = [
  LabTest(id: 't0', name: 'Complete Blood Count', price: 350),
  LabTest(id: 't1', name: 'Lipid Profile', price: 650),
  LabTest(id: 't2', name: 'Blood Sugar (Fasting)', price: 120),
  LabTest(id: 't3', name: 'HbA1c', price: 450),
  LabTest(id: 't4', name: 'Thyroid Profile', price: 550),
  LabTest(id: 't5', name: 'Liver Function Test', price: 700),
  LabTest(id: 't6', name: 'Kidney Function Test', price: 650),
  LabTest(id: 't7', name: 'Vitamin D', price: 1200),
  LabTest(id: 't8', name: 'Urine Routine', price: 200),
  LabTest(id: 't9', name: 'ECG', price: 300),
  LabTest(id: 't10', name: 'X-Ray Chest', price: 500),
  LabTest(id: 't11', name: 'Ultrasound Abdomen', price: 1100),
  LabTest(id: 't12', name: 'Dengue NS1', price: 400),
  LabTest(id: 't13', name: 'COVID RT-PCR', price: 600),
];

const List<String> ticketCategories = [
  'Appointment',
  'Order',
  'Payment',
  'Refund',
  'Account',
  'Other',
];

const List<Map<String, String>> emergencyContacts = [
  {'name': 'Ambulance', 'number': '108'},
  {'name': 'Women Helpline', 'number': '1091'},
  {'name': 'Police', 'number': '100'},
  {'name': 'Fire Dept', 'number': '101'},
  {'name': 'Child Helpline', 'number': '1098'},
  {'name': 'Disaster Mgmt', 'number': '1078'},
];

final List<Map<String, String>> healthTips = [
  {'id': 'H1', 'title': 'Stay Hydrated', 'text': 'Drink 8 glasses of water daily', 'active': '1'},
  {'id': 'H2', 'title': 'Quality Sleep', 'text': 'Aim for 7-8 hours every night', 'active': '1'},
  {'id': 'H3', 'title': 'Balanced Diet', 'text': 'Include fruits and vegetables daily', 'active': '1'},
  {'id': 'H4', 'title': 'Stay Active', 'text': 'Walk 30 minutes every day', 'active': '1'},
];

/// SUPABASE SEAM: to go live, create a SupabaseRepository with the same
/// method shapes as the getters above (e.g. Future<List<Doctor>>
/// fetchDoctors()) using package:supabase_flutter, add your project URL +
/// anon key via --dart-define, and have AppState call it instead of these
/// getters. Table shapes map 1:1 to the model classes in models.dart.

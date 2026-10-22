import 'package:flutter/material.dart';

import '../data/mock_data.dart' as catalog;
import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import '../widgets/form_kit.dart';
import 'doctor_detail_screen.dart';
import 'hospital_detail_screen.dart';
import 'lab_detail_screen.dart';
import '../app_navigator.dart';

const _quickSymptoms = [
  'Fever and body ache',
  'Chest discomfort',
  'Persistent cough',
  'Stomach pain',
  'Skin rash',
  'Headache and dizziness',
];

const _careTypes = [
  'Anything suitable',
  'Doctor',
  'Hospital',
  'Lab test',
];

const _urgencies = [
  'Routine',
  'Within a few days',
  'Urgent',
];

/// Symptom keyword → catalog specialties it points to. Used to
/// rank doctors by genuine relevance to what the patient typed —
/// Smart Care previously ignored the symptom text entirely and
/// stamped fabricated "match %" numbers on the first results
/// (audit fix 2026-10-19).
const _symptomSpecialties = <String, List<String>>{
  'chest': ['Cardiology'],
  'heart': ['Cardiology'],
  'palpitation': ['Cardiology'],
  'skin': ['Dermatology'],
  'rash': ['Dermatology'],
  'itching': ['Dermatology'],
  'acne': ['Dermatology'],
  'headache': ['Neurology'],
  'migraine': ['Neurology'],
  'dizziness': ['Neurology'],
  'nerve': ['Neurology'],
  'bone': ['Orthopedics'],
  'joint': ['Orthopedics'],
  'back pain': ['Orthopedics'],
  'fracture': ['Orthopedics'],
  'knee': ['Orthopedics'],
  'child': ['Pediatrics'],
  'baby': ['Pediatrics'],
  'infant': ['Pediatrics'],
  'pregnancy': ['Gynecology'],
  'period': ['Gynecology'],
  'ear': ['ENT'],
  'nose': ['ENT'],
  'throat': ['ENT'],
  'sinus': ['ENT'],
  'eye': ['Ophthalmology'],
  'vision': ['Ophthalmology'],
  'anxiety': ['Psychiatry'],
  'stress': ['Psychiatry'],
  'depression': ['Psychiatry'],
  'sleep': ['Psychiatry'],
  'tooth': ['Dentistry'],
  'teeth': ['Dentistry'],
  'dental': ['Dentistry'],
  'gum': ['Dentistry'],
  'stomach': ['Gastroenterology'],
  'digestion': ['Gastroenterology'],
  'acidity': ['Gastroenterology'],
  'nausea': ['Gastroenterology'],
  'abdominal': ['Gastroenterology'],
  'urine': ['Urology'],
  'urinary': ['Urology'],
  'kidney': ['Nephrology'],
  'cough': ['Pulmonology'],
  'breath': ['Pulmonology'],
  'asthma': ['Pulmonology'],
  'lung': ['Pulmonology'],
  'diabetes': ['Endocrinology'],
  'sugar': ['Endocrinology'],
  'thyroid': ['Endocrinology'],
  'hormone': ['Endocrinology'],
  'fever': ['General Physician'],
  'cold': ['General Physician'],
  'flu': ['General Physician'],
  'body ache': ['General Physician'],
  'weakness': ['General Physician'],
};

/// The catalog specialties relevant to a free-text symptom
/// description. Empty when the text names nothing recognisable —
/// callers then fall back to plain rating/distance ranking and say
/// so, rather than inventing a match score.
Set<String> relevantSpecialtiesForSymptom(String symptomText) {
  final text = symptomText.toLowerCase();
  final out = <String>{};
  if (text.trim().isEmpty) return out;
  _symptomSpecialties.forEach((keyword, specs) {
    if (text.contains(keyword)) out.addAll(specs);
  });
  // A specialty named outright in the text is relevant too.
  for (final specs in _symptomSpecialties.values) {
    for (final s in specs) {
      if (text.contains(s.toLowerCase())) out.add(s);
    }
  }
  return out;
}

/// What the free-text "Anything else?" box can honestly steer
/// (form-pages audit Patient 16: the field was collected and
/// never read). The text joins the symptom text for specialty
/// relevance, and explicit asks change the ranking: cheapest,
/// nearest, or best rated. Anything else is surfaced back to the
/// user as a note rather than silently dropped.
class CareMatchPreferences {
  final bool cheapest;
  final bool nearest;
  final bool bestRated;

  /// Asks the data cannot always honour — parsed so the result
  /// note can say plainly whether they were applied (full-check
  /// fix 2026-10-22: the form's own examples, "prefer a female
  /// doctor" and "home sample collection", were never read).
  final bool femaleDoctor;
  final bool homeCollection;

  const CareMatchPreferences({
    this.cheapest = false,
    this.nearest = false,
    this.bestRated = false,
    this.femaleDoctor = false,
    this.homeCollection = false,
  });

  bool get anySort => cheapest || nearest || bestRated;

  String get sortLabel => cheapest
      ? 'lowest fee first, as you asked'
      : nearest
          ? 'nearest first, as you asked'
          : 'best rated first, as you asked';
}

CareMatchPreferences careMatchPreferences(String notes) {
  final t = notes.toLowerCase();
  return CareMatchPreferences(
    cheapest: t.contains('cheap') ||
        t.contains('lowest fee') ||
        t.contains('budget friendly') ||
        t.contains('affordable'),
    nearest: t.contains('nearest') ||
        t.contains('near me') ||
        t.contains('close to'),
    bestRated: t.contains('best rated') ||
        t.contains('top rated') ||
        t.contains('highest rating'),
    femaleDoctor: t.contains('female') || t.contains('lady doctor'),
    homeCollection: t.contains('home collection') ||
        t.contains('home sample') ||
        t.contains('collect at home') ||
        t.contains('home visit'),
  );
}

/// Smart Care Finder: symptom input + preferences → ranked matches.
class CareMatchScreen extends StatefulWidget {
  final String initialSymptom;

  const CareMatchScreen({super.key, this.initialSymptom = ''});

  @override
  State<CareMatchScreen> createState() => _CareMatchScreenState();
}

class _CareMatchScreenState extends State<CareMatchScreen> {
  late final TextEditingController _symptom;
  late final TextEditingController _budget;
  final _notes = TextEditingController();
  String _careType = 'Anything suitable';
  String _urgency = 'Routine';
  bool _searched = false;

  double get _budgetValue =>
      double.tryParse(_budget.text) ?? 1000;

  @override
  void initState() {
    super.initState();
    _symptom = TextEditingController(text: widget.initialSymptom);
    _budget = TextEditingController(text: '1000');
  }

  @override
  void dispose() {
    _symptom.dispose();
    _budget.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // White sticky header.
            Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  bottom: BorderSide(
                      color: Theme.of(context).dividerColor),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding:
                  const EdgeInsets.fromLTRB(8, 8, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.arrow_back,
                          size: 20),
                      onPressed: () =>
                          goBack(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome,
                                size: 16,
                                color: scheme.primary),
                            const SizedBox(width: 6),
                            const Text('Smart Care Finder',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                        Text(
                            'Describe your symptoms, get matched care',
                            style: TextStyle(
                                fontSize: 11,
                                color:
                                    scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: MaxWidthBox(
                maxWidth: 720,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      20, 16, 20, 32),
                  children: [
                    RCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text('How are you feeling?',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          RKitField(
                            label: 'Describe your symptoms',
                            hint:
                                'e.g. Sharp stomach pain with nausea for two days, worse after meals',
                            controller: _symptom,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _quickSymptoms
                                .map((s) => RFilterChip(
                                      label: s,
                                      selected: _symptom.text == s,
                                      onTap: () => setState(
                                          () =>
                                              _symptom.text = s),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                              'What kind of care do you want?',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _careTypes
                                .map((t) => _segPill(
                                    t,
                                    _careType == t,
                                    () => setState(
                                        () => _careType = t)))
                                .toList(),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                              'How soon do you need it?',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _urgencies
                                .map((u) => _segPill(
                                    u,
                                    _urgency == u,
                                    () => setState(
                                        () => _urgency = u)))
                                .toList(),
                          ),
                          const SizedBox(height: 18),
                          // Full-check fix 2026-10-22: the Max
                          // distance field is gone — providers
                          // carry no real distance data, so the
                          // filter passed everything and meant
                          // nothing.
                          RKitField(
                            label: 'Budget (₹)',
                            hint: 'e.g. 500',
                            controller: _budget,
                            keyboardType:
                                TextInputType.number,
                          ),
                          const SizedBox(height: 14),
                          RKitField(
                            label: 'Anything else? (optional)',
                            hint:
                                'e.g. prefer a female doctor, home sample collection',
                            controller: _notes,
                          ),
                          const SizedBox(height: 18),
                          RButton(
                            label: 'Find my care match',
                            icon: Icons.auto_awesome,
                            fullWidth: true,
                            onPressed: () => setState(
                                () => _searched = true),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: Text(
                              '⚕️ Guidance only, not a medical diagnosis. Always consult a qualified doctor.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_searched) ...[
                      const SizedBox(height: 20),
                      const Text('Your matches',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Builder(builder: (context) {
                        final matches = _matches(state);
                        if (matches.isEmpty) {
                          return const Padding(
                            padding:
                                EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              'No matches found for your criteria. Try increasing your budget.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey),
                            ),
                          );
                        }
                        return Column(children: matches);
                      }),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Segmented pill: selected = orange, unselected = bordered.
  Widget _segPill(
      String label, bool selected, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primary
          : Theme.of(context).cardColor,
      shape: StadiumBorder(
        side: selected
            ? BorderSide.none
            : BorderSide(
                color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : scheme.onSurface)),
        ),
      ),
    );
  }

  List<Widget> _matches(AppState state) {
    final out = <Widget>[];
    final urgent = _urgency == 'Urgent';
    final budget = _budgetValue;
    final symptomText = _symptom.text.trim();
    // The "Anything else?" text is read now (audit Patient 16):
    // it joins the symptom text for specialty relevance and its
    // explicit asks (cheapest / nearest / best rated) steer the
    // ranking within relevant matches.
    final notesText = _notes.text.trim();
    final prefs = careMatchPreferences(notesText);
    final relevantSpecs =
        relevantSpecialtiesForSymptom('$symptomText $notesText');
    bool doctorRelevant(Doctor d) => relevantSpecs
        .any((s) => s.toLowerCase() == d.specialty.toLowerCase());
    Widget staggered(Widget card) =>
        StaggerItem(index: out.length % 6, child: card);
    if (_careType == 'Anything suitable' || _careType == 'Doctor') {
      final docs = state.activeDoctors
          .where((d) => d.fee <= budget)
          .toList()
        ..sort((a, b) {
          // Symptom-relevant specialties first, then urgency
          // (soonest typical wait first when the need is not
          // routine — full-check fix 2026-10-22: urgency used to
          // change nothing for doctors), then the ranking the
          // patient asked for in "Anything else?" (default:
          // rating). No invented percentages, no fake distances.
          final ra = doctorRelevant(a) ? 0 : 1;
          final rb = doctorRelevant(b) ? 0 : 1;
          if (ra != rb) return ra.compareTo(rb);
          if (_urgency != 'Routine') {
            final byWait = a.waitMin.compareTo(b.waitMin);
            if (byWait != 0) return byWait;
          }
          if (prefs.cheapest) {
            final byFee = a.fee.compareTo(b.fee);
            if (byFee != 0) return byFee;
          }
          final byRating = b.rating.compareTo(a.rating);
          if (byRating != 0) return byRating;
          return a.fee.compareTo(b.fee);
        });
      for (final d in docs.take(3)) {
        final relevant = doctorRelevant(d);
        out.add(staggered(_matchCard(
          kind: 'Doctor',
          icon: Icons.medical_services,
          name: d.name,
          sub: '${d.specialty} • ${inr(d.fee)}',
          rating: d.rating,
          tag: relevant ? 'Matches your symptoms' : null,
          reason: relevant
              ? '${d.specialty} specialist — relevant to the symptoms you described, and within your budget.'
              : 'Highly rated ${d.specialty} within your budget.',
          onTap: () {
            if (!checkLogin(context, 'Please login to view details')) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => DoctorDetailScreen(doctor: d)),
            );
          },
        )));
      }
    }
    if (_careType == 'Anything suitable' || _careType == 'Hospital') {
      // Budget applies to hospitals too (full-check fix
      // 2026-10-22: it used to filter doctors only). A hospital
      // with no consultation fee on record (0) is not excluded.
      final hs = state.activeHospitals
          .where((h) => h.fee == 0 || h.fee <= budget)
          .toList()
        ..sort((a, b) {
          if (urgent) {
            final ia = a.hasIcu ? 0 : 1;
            final ib = b.hasIcu ? 0 : 1;
            if (ia != ib) return ia.compareTo(ib);
          }
          if (prefs.cheapest) {
            final byFee = a.fee.compareTo(b.fee);
            if (byFee != 0) return byFee;
          }
          final byRating = b.rating.compareTo(a.rating);
          if (byRating != 0) return byRating;
          return a.name.compareTo(b.name);
        });
      for (final h in hs.take(2)) {
        out.add(staggered(_matchCard(
          kind: 'Hospital',
          icon: Icons.local_hospital_outlined,
          name: h.name,
          sub: h.location,
          rating: h.rating,
          tag: h.hasIcu ? 'ICU available' : null,
          reason: urgent && h.hasIcu
              ? 'Has ICU facilities — a safer pick for urgent care.'
              : 'Well-rated hospital within your budget.',
          onTap: () {
            if (!checkLogin(context, 'Please login to view details')) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      HospitalDetailScreen(hospital: h)),
            );
          },
        )));
      }
    }
    if (_careType == 'Anything suitable' || _careType == 'Lab test') {
      // Tests whose name/category shares a word with the symptom
      // text are the honest "related tests" signal.
      final words = '$symptomText $notesText'
          .toLowerCase()
          .split(RegExp(r'[^a-z]+'))
          .where((w) => w.length > 3)
          .toSet();
      // Real catalogue tests (full-check fix 2026-10-22: this
      // read the mock labTests list). Budget for a lab = it offers
      // at least one test within budget; a lab whose tests are not
      // loaded is not excluded on a guess.
      final relatedTests = catalog.labTests.where((t) {
        final hay = '${t.name} ${t.category}'.toLowerCase();
        return words.any((w) => hay.contains(w));
      }).toList();
      double cheapestFor(String labId) {
        var best = double.infinity;
        for (final t in catalog.labTests) {
          if (t.labId == labId && t.price < best) best = t.price;
        }
        return best;
      }

      bool offersHome(String labId) => catalog.labTests
          .any((t) => t.labId == labId && t.homeCollection);
      int turnaroundHours(Lab l) {
        final m = RegExp(r'(\d+)').firstMatch(l.turnaround);
        if (m != null) return int.parse(m.group(1)!);
        return l.turnaround.toLowerCase().contains('same') ? 12 : 48;
      }

      final ls = state.activeLabs
          .where((l) {
            final tests =
                catalog.labTests.where((t) => t.labId == l.id).toList();
            return tests.isEmpty ||
                tests.any((t) => t.price <= budget);
          })
          .toList()
        ..sort((a, b) {
          if (prefs.homeCollection) {
            final ha = offersHome(a.id) ? 0 : 1;
            final hb = offersHome(b.id) ? 0 : 1;
            if (ha != hb) return ha.compareTo(hb);
          }
          if (urgent) {
            final byTat =
                turnaroundHours(a).compareTo(turnaroundHours(b));
            if (byTat != 0) return byTat;
          }
          if (prefs.cheapest) {
            final byPrice =
                cheapestFor(a.id).compareTo(cheapestFor(b.id));
            if (byPrice != 0) return byPrice;
          }
          return b.rating.compareTo(a.rating);
        });
      for (final l in ls.take(2)) {
        out.add(staggered(_matchCard(
          kind: 'Lab',
          icon: Icons.science_outlined,
          name: l.name,
          sub:
              '${l.testCount} tests • Report in ${l.turnaround}',
          rating: l.rating,
          tag: prefs.homeCollection && offersHome(l.id)
              ? 'Home collection'
              : relatedTests.isNotEmpty
                  ? 'Symptom-related tests'
                  : null,
          reason: relatedTests.isNotEmpty
              ? 'Offers tests related to your symptoms, e.g. ${relatedTests.first.name}.'
              : 'Highly rated lab with tests within your budget.',
          onTap: () {
            if (!checkLogin(context, 'Please login to view details')) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => LabDetailScreen(lab: l)),
            );
          },
        )));
      }
    }
    if (notesText.isNotEmpty && out.isNotEmpty) {
      // Say plainly what the note did and did not change
      // (full-check fix 2026-10-22). "Nearest" cannot be honoured
      // — providers carry no real distance data — and doctor
      // gender is not in the data at all; both are named here
      // instead of being silently dropped.
      final effects = <String>[];
      if (prefs.cheapest || prefs.bestRated) {
        effects.add('sorted by ${prefs.sortLabel}');
      }
      if (prefs.nearest) {
        effects.add(
            'you asked for nearest first, but distances are not available yet, so ranking used rating and fee');
      }
      if (prefs.femaleDoctor) {
        effects.add(
            'doctor gender is not in our data yet, so that preference could not be applied');
      }
      if (prefs.homeCollection) {
        effects.add('labs offering home collection were preferred');
      }
      if (effects.isEmpty) effects.add('used for specialty matching');
      out.insert(
        0,
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: RCard(
            child: Text(
              'Your note: "$notesText" — ${effects.join('; ')}.',
              style: TextStyle(
                  fontSize: 12.5,
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      );
    }
    // No self-appended empty card (full-check fix 2026-10-22):
    // the results Builder owns the empty state.
    return out;
  }

  Widget _matchCard({
    required String kind,
    required IconData icon,
    required String name,
    required String sub,
    required double rating,
    required String? tag,
    required String reason,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: RCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      Text(kind,
                          style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (tag != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: scheme.primary
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(tag,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: scheme.primary)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(reason,
                style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(
              children: [
                RStat(
                    icon: Icons.star,
                    text: rating.toStringAsFixed(1)),
                const SizedBox(width: 14),
                Expanded(
                  child: RStat(icon: Icons.info_outline, text: sub),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

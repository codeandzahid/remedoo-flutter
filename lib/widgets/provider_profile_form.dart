import 'package:flutter/material.dart';

import '../services/supabase_repository.dart';
import '../utils/working_hours.dart';
import 'widgets.dart';
import 'form_kit.dart';
import 'working_hours_editor.dart';

/// Profile form for hospital / lab / pharmacy partners
/// (form-pages audit Panelist 10 / M13 / M18: only doctors had a
/// profile form — the other three partner types could not edit
/// their name, phone, location or hours anywhere, and the admin
/// CRUD was the only way their public record ever changed).
/// Saves through the same own-record update the doctor form uses.
class ProviderProfileForm extends StatefulWidget {
  final String table; // hospitals | labs | pharmacies
  final Map<String, dynamic>? profile;
  final SupabaseRepository repo;
  final VoidCallback onSaved;

  const ProviderProfileForm({
    super.key,
    required this.table,
    required this.profile,
    required this.repo,
    required this.onSaved,
  });

  @override
  State<ProviderProfileForm> createState() =>
      _ProviderProfileFormState();
}

class _ProviderProfileFormState extends State<ProviderProfileForm> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _location;
  late final TextEditingController _beds;
  late final TextEditingController _services;
  late bool _icu;
  late Map<String, DayHours> _hoursValue;
  bool _saving = false;

  bool get _isHospital => widget.table == 'hospitals';
  bool get _isLab => widget.table == 'labs';

  @override
  void initState() {
    super.initState();
    final p = widget.profile ?? {};
    _name = TextEditingController(text: '${p['name'] ?? ''}');
    _phone = TextEditingController(text: '${p['phone'] ?? ''}');
    _location = TextEditingController(text: '${p['location'] ?? ''}');
    _beds = TextEditingController(
        text: '${p['total_beds'] ?? p['beds'] ?? ''}');
    final services = p['services'];
    _services = TextEditingController(
      text: services is List
          ? services.join(', ')
          : '${services ?? ''}',
    );
    _icu = p['icu_available'] == true;
    _hoursValue = parseWorkingHours(p['working_hours']);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _location.dispose();
    _beds.dispose();
    _services.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final values = <String, dynamic>{
      'name': _name.text.trim(),
      'phone': _phone.text.trim(),
      'location': _location.text.trim(),
      'working_hours': workingHoursToJson(_hoursValue),
    };
    if (_isHospital) {
      final beds = int.tryParse(_beds.text.trim());
      if (beds != null) {
        values['total_beds'] = beds;
        values['beds'] = beds;
      }
      values['icu_available'] = _icu;
    }
    if (_isLab) {
      values['services'] = _services.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    final ok =
        await widget.repo.updateOwnProviderRecord(widget.table, values);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Profile saved.'
            : 'Could not save. Try again.'),
      ),
    );
    if (ok) widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RSectionHeader(
            title: 'Profile',
            subtitle: 'What patients see about you',
          ),
          const SizedBox(height: 12),
          RKitField(controller: _name, label: 'Name'),
          const SizedBox(height: 12),
          RKitField(
            controller: _phone,
            label: 'Phone',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          RKitField(controller: _location, label: 'Location / address'),
          if (_isHospital) ...[
            const SizedBox(height: 12),
            RKitField(
              controller: _beds,
              label: 'Total beds',
              keyboardType: TextInputType.number,
            ),
            RFormSwitchTile(
              title: 'ICU available',
              value: _icu,
              onChanged: (v) => setState(() => _icu = v),
            ),
          ],
          if (_isLab) ...[
            const SizedBox(height: 12),
            RKitField(
              controller: _services,
              label: 'Services / tests offered',
              hint: 'Blood Test, X-Ray, MRI — comma separated',
              maxLines: 2,
            ),
          ],
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Working hours',
                style:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 4),
          WorkingHoursEditor(
            initial: _hoursValue,
            onChanged: (v) => _hoursValue = v,
          ),
          const SizedBox(height: 16),
          RButton(
            label: _saving ? 'Saving…' : 'Save profile',
            fullWidth: true,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

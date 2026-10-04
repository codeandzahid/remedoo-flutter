import 'package:flutter/material.dart';

import '../models.dart';
import '../responsive/animations.dart';
import '../responsive/responsive.dart';
import '../theme.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';
import 'booking_screen.dart';

/// Doctor profile: single column on phones, info + booking panel on larger.
/// Mirrors the React DoctorDetail page: profile card, About, Hospital,
/// Working Hours, sticky Book Appointment CTA.
class DoctorDetailScreen extends StatelessWidget {
  final Doctor doctor;

  const DoctorDetailScreen({super.key, required this.doctor});

  @override
  Widget build(BuildContext context) {
    if (!AppStateScope.of(context).isSignedIn) {
      return const GuestGate(message: 'Please login to view details');
    }
    final d = doctor;
    final compact = context.isCompact;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Profile'),
        actions: [FavoriteButton(favKey: 'doctor:${d.id}')],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DetailSplit(
            main: Column(
              children: [
                _profileCard(context, d),
                const SizedBox(height: 12),
                _aboutCard(context, d),
                const SizedBox(height: 12),
                _hoursCard(context),
              ],
            ),
            side: _bookingPanel(context, d),
          ),
          if (compact) const SizedBox(height: 80),
        ],
      ),
      bottomSheet: compact ? _bookBar(context, d) : null,
    );
  }

  Widget _profileCard(BuildContext context, Doctor d) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'doctor-avatar-${d.id}',
                child: InitialsAvatar(name: d.name, radius: 36),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            d.name,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (d.verified) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.verified,
                              size: 20, color: scheme.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      d.specialty,
                      style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        RRatingPill(rating: d.rating),
                        const SizedBox(width: 12),
                        Icon(Icons.work_outline,
                            size: 15,
                            color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '${d.expYears} yrs exp',
                          style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.business_outlined,
                            size: 15,
                            color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            d.hospital,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    inr(d.fee),
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '/ consultation',
                    style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _aboutCard(BuildContext context, Doctor d) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('About',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            d.about,
            style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }


  Widget _hoursCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              const Text('Working Hours',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          _hoursRow(context, 'Mon – Sat', '09:00 AM – 05:00 PM', false),
          _hoursRow(context, 'Sunday', 'Closed', true),
        ],
      ),
    );
  }

  Widget _hoursRow(
      BuildContext context, String day, String hours, bool closed) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(day,
              style: TextStyle(
                  fontSize: 14, color: scheme.onSurfaceVariant)),
          Text(hours,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: closed
                      ? RemedooTheme.destructive
                      : scheme.onSurface)),
        ],
      ),
    );
  }

  /// Booking panel: sticky bottom bar on phones, side panel on larger screens.
  Widget _bookingPanel(BuildContext context, Doctor d) {
    final scheme = Theme.of(context).colorScheme;
    return RCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Book Appointment',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              RRatingPill(rating: d.rating),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${d.expYears} yrs experience',
                    style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Consultation fee',
              style: TextStyle(
                  fontSize: 13, color: scheme.onSurfaceVariant)),
          Text(inr(d.fee),
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: scheme.primary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule,
                  size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                  child: Text('Available Mon–Sat, 9 AM – 5 PM',
                      style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant))),
            ],
          ),
          const SizedBox(height: 16),
          RButton(
            label: 'Book Appointment',
            icon: Icons.calendar_month,
            fullWidth: true,
            onPressed: () {
              if (!checkLogin(
                  context, 'Please login to book appointments')) {
                return;
              }
              pushPage(
                context,
                BookingScreen(
                  kind: 'doctor',
                  refId: d.id,
                  title: d.name,
                  subtitle: d.specialty,
                  place: d.hospital,
                  fee: d.fee,
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          RButton(
            label: 'Call Clinic',
            icon: Icons.call,
            variant: RButtonVariant.outline,
            fullWidth: true,
            onPressed: () {
              showResponsiveDialog(
                context,
                (_) => AlertDialog(
                  title: const Text('Call clinic'),
                  content: Text(
                      'Calling ${d.hospital} reception… (demo)'),
                  actions: [
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _bookBar(BuildContext context, Doctor d) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: RButton(
          label: 'Book Appointment',
          icon: Icons.calendar_month,
          fullWidth: true,
          onPressed: () {
            if (!checkLogin(
                context, 'Please login to book appointments')) {
              return;
            }
            pushPage(
              context,
              BookingScreen(
                kind: 'doctor',
                refId: d.id,
                title: d.name,
                subtitle: d.specialty,
                place: d.hospital,
                fee: d.fee,
              ),
            );
          },
        ),
      ),
    );
  }
}

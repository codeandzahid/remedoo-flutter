import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens Google Maps with directions/search for a real place.
///
/// Uses the provider's actual [name] and [address] — no demo data.
Future<void> openDirections(
  BuildContext context, {
  required String name,
  required String address,
}) async {
  final query = Uri.encodeComponent(
      '$name, $address'.trim().replaceAll(RegExp(r'^,\s*'), ''));
  final url =
      Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
  try {
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Maps app.')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Maps app.')),
      );
    }
  }
}

/// Opens the phone dialer with a real phone [number].
Future<void> dialNumber(BuildContext context, String number) async {
  final url = Uri(scheme: 'tel', path: number);
  try {
    final ok = await launchUrl(url);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not dial $number.')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not dial $number.')),
      );
    }
  }
}

/// Fetches the device's real location and reverse-geocodes it into a
/// human-readable address string. Returns null when location is
/// unavailable or permission is denied.
Future<String?> fetchCurrentAddress() async {
  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    try {
      final marks = await Geocoding().placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (marks.isNotEmpty) {
        final m = marks.first;
        final parts = [
          m.street,
          m.subLocality,
          m.locality,
          m.administrativeArea,
          m.postalCode,
          m.country,
        ].where((s) => s != null && s.trim().isNotEmpty).toList();
        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (_) {
      // Reverse geocoding failed — fall back to coordinates.
    }
    return 'Lat ${pos.latitude.toStringAsFixed(5)}, '
        'Lng ${pos.longitude.toStringAsFixed(5)}';
  } catch (_) {
    return null;
  }
}

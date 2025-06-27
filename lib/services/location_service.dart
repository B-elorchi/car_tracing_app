import 'dart:async'; // ✅ Nécessaire pour Timer
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationService {
  final String userId;
  Timer? _timer;

  LocationService({required this.userId});

  Future<void> startTracking() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print("❌ Permission refusée.");
        return;
      }
    }

    print("✅ Permission GPS accordée. Démarrage du suivi...");

    _timer = Timer.periodic(const Duration(seconds: 10), (Timer t) async {
      try {
        Position pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );

        await _sendLocation(pos); // Envoie la position à Firebase ou autre
      } catch (e) {
        print("❌ Erreur de localisation : $e");
      }
    });
  }

  Future<void> stopTracking() async {
    _timer?.cancel();
    print("🛑 Suivi GPS arrêté.");
  }

  Future<void> _sendLocation(Position pos) async {
    await FirebaseFirestore.instance
        .collection('locations')
        .doc(userId)
        .set({
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'timestamp': FieldValue.serverTimestamp(),
    });

    print("📡 Position enregistrée dans Firestore pour $userId : ${pos.latitude}, ${pos.longitude}");
  }
}
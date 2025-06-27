// lib/controller/GeolocalisationController.dart
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class LocationService {
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;

  // Check if location services are enabled and request permissions
  Future<bool> _checkAndRequestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Service de localisation désactivé');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permission de localisation refusée');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permission de localisation refusée définitivement');
    }
    return true;
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  // Check if the device is within the geofence
  bool _isWithinGeofence({
    required double currentLat,
    required double currentLon,
    required double centerLat,
    required double centerLon,
    required double radius,
  }) {
    final distance = _calculateDistance(currentLat, currentLon, centerLat, centerLon);
    return distance <= radius;
  }

  // Start location tracking for a reservation
  Future<void> startLocationTracking({
    required String reservationId,
    required Map<String, dynamic> allowedZone,
  }) async {
    if (_isTracking) return;

    try {
      await _checkAndRequestPermissions();

      // Start foreground service
      await _startForegroundService();

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) async {
        try {
          // Send location update to Firestore
          await sendLocationUpdate(reservationId, position);

          // Check geofence
          final centerLat = allowedZone['center']['latitude'] as double;
          final centerLon = allowedZone['center']['longitude'] as double;
          final radius = allowedZone['radius'] as double;

          if (!_isWithinGeofence(
            currentLat: position.latitude,
            currentLon: position.longitude,
            centerLat: centerLat,
            centerLon: centerLon,
            radius: radius,
          )) {
            // Log geofence exit to Firestore
            await FirebaseFirestore.instance.collection('geofence_events').add({
              'reservationId': reservationId,
              'eventType': 'exit',
              'latitude': position.latitude,
              'longitude': position.longitude,
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
          print('Erreur lors du traitement de la position: $e');
        }
      });
      _isTracking = true;
    } catch (e) {
      print('Erreur lors du démarrage du suivi: $e');
      rethrow;
    }
  }

  // Stop location tracking
  Future<void> stopLocationTracking() async {
    if (!_isTracking) return;

    await _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;

    // Stop foreground service
    await FlutterForegroundTask.stopService();
  }

  // Get current location
  Future<Position> getCurrentLocation() async {
    await _checkAndRequestPermissions();
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // Send location update to Firestore
  Future<void> sendLocationUpdate(String reservationId, Position position) async {
    try {
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservationId)
          .collection('locations')
          .doc(DateTime.now().millisecondsSinceEpoch.toString())
          .set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Erreur lors de l\'envoi de la position: $e');
      rethrow;
    }
  }

  // Start foreground service for Android
   _startForegroundService()  {
    // Initialize the foreground task
   FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'location_service',
        channelName: 'Location Tracking',
        channelDescription:
        'This notification keeps the app running for location tracking.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions:  ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWifiLock: true,
        allowWakeLock: true,
      ),
    );

    // Start the foreground service
    var success =  FlutterForegroundTask.startService(
      notificationTitle: 'Location Tracking Active',
      notificationText: 'Monitoring your location for reservations',
    );


  }
}
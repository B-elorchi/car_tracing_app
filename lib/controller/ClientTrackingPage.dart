import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class ClientTrackingPage extends StatefulWidget {
  const ClientTrackingPage({super.key});

  @override
  State<ClientTrackingPage> createState() => _ClientTrackingPageState();
}

class _ClientTrackingPageState extends State<ClientTrackingPage> {
  final MapController _mapController = MapController();

  // La position de ce client/appareil
  LatLng? _currentDevicePosition;

  // Collection de tous les marqueurs de véhicules (y compris ce client)
  final Map<String, Marker> _vehicleMarkers = {};

  bool _isTracking = false; // Indique si ce client envoie sa propre position
  StreamSubscription<Position>? _positionStream; // Abonnement pour la position de ce client

  double _currentZoom = 15.0;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _reservationsSubscription;
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _locationSubscriptions = {};

  // Variables pour le suivi du signal GPS global (pour tous les véhicules)
  bool _isGpsSignalLost = true; // Par défaut, on considère le signal perdu au démarrage
  DateTime? _lastOverallGpsUpdate; // Timestamp de la dernière mise à jour de n'importe quel véhicule
  Timer? _gpsCheckTimer;
  final Duration _gpsLostThreshold = const Duration(seconds: 30); // Seuil de 30 secondes sans mise à jour

  // Zone de Marrakech (les coordonnées de votre exemple)
  final List<LatLng> polygonZone = [
    LatLng(31.700, -8.030),
    LatLng(31.700, -7.930),
    LatLng(31.570, -7.930),
    LatLng(31.570, -8.030),
    LatLng(31.700, -8.030), // fermer le polygon
  ];

  // ID de réservation fixe pour la démo du client
  final String reservationId = "demo-reservation-client";

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _startGpsSignalCheckTimer(); // Démarrer le timer de vérification GPS global
    _startListeningToOtherVehicles(); // Commencer à écouter les autres véhicules
  }

  // --- Fonctions de Notifications Locales ---
  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(settings);
  }

  Future<void> _showExitZoneNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'geofence_channel',
      'Sortie de zone',
      channelDescription: 'Notification quand la voiture sort de zone',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
      0,
      '⚠️ Alerte de zone',
      'La voiture a quitté la zone autorisée !',
      notificationDetails,
    );
  }

  // --- Fonctions de Suivi en Arrière-plan (Foreground Service) ---
  Future<void> _startForegroundService() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'location_service',
        channelName: 'Location Tracking',
        channelDescription: 'Suivi GPS actif',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    await FlutterForegroundTask.startService(
      notificationTitle: 'Tracking GPS actif',
      notificationText: 'Suivi de position en cours...',
    );
  }

  // --- Logique du Client (envoi de sa propre position) ---
  void _startTracking() async {
    // Demander la permission de localisation
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        // Gérer le cas où les permissions sont refusées de façon permanente
        return Future.error('Location permissions are permanently denied, we cannot request permissions.');
      }
      if (permission == LocationPermission.denied) {
        // Gérer le cas où les permissions sont refusées
        return Future.error('Location permissions are denied (actual value: $permission).');
      }
    }

    await _startForegroundService();

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Mettre à jour si la position change de 10 mètres
      ),
    ).listen((position) async {
      final latLng = LatLng(position.latitude, position.longitude);

      if (!mounted) return; // S'assurer que le widget est toujours monté avant setState

      setState(() {
        _currentDevicePosition = latLng;
        // Mettre à jour le marqueur de ce client
        _vehicleMarkers[reservationId] = _createVehicleMarker(
          reservationId, // ID unique pour ce client
          latLng,
          'Mon Véhicule', // Nom pour ce client
          isCurrentDevice: true, // Pour distinguer ce marqueur
        );
      });

      _mapController.move(latLng, _currentZoom);

      // Mettre à jour le timestamp global de la dernière mise à jour GPS
      _lastOverallGpsUpdate = DateTime.now();
      _checkGpsSignalStatus(); // Vérifier l'état du GPS immédiatement

      // Envoi de la position à Firestore
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservationId)
          .collection('locations')
          .add({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Vérification de la géofence
      bool isInside = _isPointInPolygon(latLng, polygonZone);
      if (!isInside) {
        await FirebaseFirestore.instance.collection('geofence_events').add({
          'reservationId': reservationId,
          'eventType': 'exit',
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        });
        await _showExitZoneNotification();
      }
    },
        onError: (error) {
          print("Erreur de suivi GPS du client: $error");
          // Gérer l'erreur, par exemple, afficher un message à l'utilisateur
        });

    setState(() => _isTracking = true);
  }

  void _stopTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;
    setState(() {
      _isTracking = false;
      _vehicleMarkers.remove(reservationId); // Retirer le marqueur du client
    });
    await FlutterForegroundTask.stopService();
  }

  // --- Logique d'affichage des autres véhicules (copiée de l'Admin page) ---
  void _startListeningToOtherVehicles() {
    _reservationsSubscription = _firestore.collection('reservations')
        .snapshots()
        .listen((reservationsSnapshot) {
      final Set<String> activeReservationIds = reservationsSnapshot.docs.map((doc) => doc.id).toSet();
      final Set<String> currentlyTrackedIds = _locationSubscriptions.keys.toSet();

      // Arrêter le suivi des véhicules qui ne sont plus dans les réservations actives
      // Sauf pour le véhicule de ce client s'il est en train de suivre
      for (var removedId in currentlyTrackedIds.difference(activeReservationIds)) {
        if (removedId != reservationId) { // Ne pas annuler l'abonnement du client s'il est actif
          _locationSubscriptions[removedId]?.cancel();
          _locationSubscriptions.remove(removedId);
          if (mounted) {
            setState(() {
              _vehicleMarkers.remove(removedId);
            });
          }
        }
      }

      // Démarrer ou mettre à jour le suivi des véhicules actifs
      for (var reservationDoc in reservationsSnapshot.docs) {
        final currentReservationId = reservationDoc.id;

        // Si c'est le véhicule de ce client, on ne crée pas un écouteur supplémentaire ici
        // car sa position est déjà gérée par _startTracking.
        if (currentReservationId == reservationId && _isTracking) {
          continue; // Skip, le marqueur de ce client est géré par _startTracking
        }

        // Si l'écouteur n'existe pas encore pour ce véhicule, on le crée.
        if (!_locationSubscriptions.containsKey(currentReservationId)) {
          _locationSubscriptions[currentReservationId] = _firestore.collection('reservations')
              .doc(currentReservationId)
              .collection('locations')
              .orderBy('timestamp', descending: true)
              .limit(1) // On ne veut que la dernière position
              .snapshots()
              .listen((locationSnapshot) async {
            if (!mounted) return; // S'assurer que le widget est toujours monté

            if (locationSnapshot.docs.isEmpty) {
              // Si pas de données de localisation récentes pour ce véhicule, le retirer de la carte
              setState(() {
                _vehicleMarkers.remove(currentReservationId);
              });
              return;
            }

            final locationData = locationSnapshot.docs.first.data();
            final position = LatLng(locationData['latitude'], locationData['longitude']);
            final Timestamp firebaseTimestamp = locationData['timestamp'];
            final DateTime lastLocationTime = firebaseTimestamp.toDate();

            // Mettre à jour le timestamp global de la dernière mise à jour reçue
            if (_lastOverallGpsUpdate == null || lastLocationTime.isAfter(_lastOverallGpsUpdate!)) {
              _lastOverallGpsUpdate = lastLocationTime;
              _checkGpsSignalStatus();
            }

            // Récupérer les infos du véhicule (modèle) depuis le document de réservation principal
            final reservationDocData = reservationDoc.data();
            final vehicleName = reservationDocData?['vehicleModel'] ?? 'Véhicule inconnu';

            setState(() {
              _vehicleMarkers[currentReservationId] = _createVehicleMarker(
                currentReservationId,
                position,
                vehicleName,
                isCurrentDevice: false, // Ce n'est pas le marqueur de ce client
              );
            });
          },
              onError: (error) {
                print("Erreur lors de la récupération de la localisation pour $currentReservationId: $error");
              });
        }
      }
    });
  }

  // --- Logique du Signal GPS Perdu ---
  void _startGpsSignalCheckTimer() {
    _gpsCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkGpsSignalStatus();
    });
  }

  void _checkGpsSignalStatus() {
    bool newStatus = true;

    if (_lastOverallGpsUpdate != null) {
      final now = DateTime.now();
      final difference = now.difference(_lastOverallGpsUpdate!);
      if (difference <= _gpsLostThreshold) {
        newStatus = false;
      }
    }

    if (mounted && _isGpsSignalLost != newStatus) {
      setState(() {
        _isGpsSignalLost = newStatus;
      });
    }
  }

  // --- Fonction pour créer un marqueur de véhicule personnalisé ---
  Marker _createVehicleMarker(String id, LatLng position, String vehicleName, {required bool isCurrentDevice}) {
    // Déterminer la couleur de la bordure du marqueur
    Color markerBorderColor;
    if (isCurrentDevice) {
      // Pour le véhicule de ce client, utilisez une couleur distincte (ex: bleu)
      markerBorderColor = Colors.blue;
    } else {
      // Pour les autres véhicules, vérifiez s'ils sont dans la zone de Marrakech
      final bool isInZone = _isPointInPolygon(position, polygonZone);
      markerBorderColor = isInZone ? Colors.green : Colors.red;
    }

    return Marker(
      point: position,
      width: 60,
      height: 60,
      child: Tooltip(
        message: vehicleName,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: markerBorderColor,
              width: 3,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Image.asset(
            'images/iconevoiture.png', // Votre icône de voiture
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  // --- Algorithme Point in Polygon (Ray Casting) ---
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.isEmpty) return false;
    int intersectCount = 0;
    for (int i = 0; i < polygon.length; i++) {
      final LatLng p1 = polygon[i];
      final LatLng p2 = polygon[(i + 1) % polygon.length];

      if (((p1.latitude <= point.latitude && point.latitude < p2.latitude) ||
          (p2.latitude <= point.latitude && point.latitude < p1.latitude)) &&
          (point.longitude < (p2.longitude - p1.longitude) * (point.latitude - p1.latitude) /
              (p2.latitude - p1.latitude) + p1.longitude)) {
        intersectCount++;
      }
    }
    return (intersectCount % 2) == 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Suivi en temps réel"),
        actions: [
          IconButton(
            icon: Icon(_isTracking ? Icons.stop_circle : Icons.play_arrow),
            onPressed: _isTracking ? _stopTracking : _startTracking,
          )
        ],
      ),
      body: Stack( // Utilisation d'un Stack pour superposer le bandeau GPS
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: polygonZone[0], // Centre initial sur la zone de démo
              initialZoom: _currentZoom,
              onPositionChanged: (position, hasGesture) {
                // Mettre à jour le zoom quand l'utilisateur zoome/dézoome
                if (position.zoom != null && position.zoom != _currentZoom) {
                  setState(() {
                    _currentZoom = position.zoom!;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.projectkhadija',
              ),
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: polygonZone,
                    color: Colors.red.withOpacity(0.2), // Couleur du polygone de zone
                    borderColor: Colors.red,
                    borderStrokeWidth: 2,
                  )
                ],
              ),
              // Afficher tous les marqueurs de véhicules (y compris le client si actif)
              MarkerLayer(
                markers: _vehicleMarkers.values.toList(),
              ),
            ],
          ),
          // Conditionnel pour afficher le bandeau "GPS Signal Lost"
          if (_isGpsSignalLost)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red[700],
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber, color: Colors.white, size: 28),
                    SizedBox(width: 10),
                    Text(
                      'GPS Signal Lost',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stopTracking(); // Arrête le suivi du client
    _reservationsSubscription?.cancel(); // Annule l'écoute des réservations
    _gpsCheckTimer?.cancel(); // Annule le timer de vérification GPS
    // Annule toutes les souscriptions de localisation individuelles des véhicules
    _locationSubscriptions.forEach((key, subscription) => subscription.cancel());
    _locationSubscriptions.clear();
    _mapController.dispose();
    super.dispose();
  }
}
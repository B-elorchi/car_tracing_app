import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // NOUVEL IMPORT POUR FIREBASE

class GeoUtils {
  static bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    double x = point.latitude;
    double y = point.longitude;
    bool inside = false;

    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].latitude;
      final yi = polygon[i].longitude;
      final xj = polygon[j].latitude;
      final yj = polygon[j].longitude;

      final intersect = ((yi > y) != (yj > y)) &&
          (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }
}

class AdminLiveTrackingPage extends StatefulWidget {
  const AdminLiveTrackingPage({super.key});

  @override
  State<AdminLiveTrackingPage> createState() => _AdminLiveTrackingPageState();
}

class _AdminLiveTrackingPageState extends State<AdminLiveTrackingPage> {
  final MapController _mapController = MapController();

  // Cette zone est maintenant la grande zone de Marrakech pour l'affichage et la logique d'alerte
  // Elle doit correspondre EXACTEMENT à MARRAKECH_ALERT_ZONE dans votre backend Node.js
  final List<LatLng> _marrakechZone = [
    const LatLng(31.670, -8.040),
    const LatLng(31.700, -7.950),
    const LatLng(31.630, -7.900),
    const LatLng(31.620, -7.880),
    const LatLng(31.580, -7.980),
    const LatLng(31.550, -8.050),
    const LatLng(31.600, -8.150),
    const LatLng(31.650, -8.100),
    const LatLng(31.670, -8.040), // Fermeture du polygone
  ];

  static const String _apiBaseUrl = 'http://10.0.2.2:3000';
  Map<String, Marker> _markers = {};
  StreamSubscription? _sseSubscription;
  Timer? _alertCheckTimer;
  Map<String, dynamic>? _selectedVehicleDetails;

  // REMOVED: final Set<String> _alertedPlates = {}; // Plus besoin de cette logique de dédoublonnage ici

  @override
  void initState() {
    super.initState();
    _fetchVehicles();
    _startSSE();
    _startAlertChecking(); // Démarrage du timer de vérification des alertes
  }

  Future<void> _fetchVehicles() async {
    try {
      final response = await http.get(Uri.parse('$_apiBaseUrl/api/vehicles'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _updateMarkers(data['data']);
        }
      }
    } catch (e) {
      _showError('Erreur de connexion lors de la récupération des véhicules.');
      debugPrint('Erreur fetchVehicles: $e'); // Pour le débogage
    }
  }

  void _updateMarkers(List<dynamic> vehicles) {
    final updatedMarkers = <String, Marker>{};

    for (var vehicle in vehicles) {
      final plate = vehicle['plate'] as String? ?? 'Inconnu';
      final lat = vehicle['location']?['latitude'];
      final lng = vehicle['location']?['longitude'];
      final speed = vehicle['speed']?.toStringAsFixed(1) ?? '0.0';
      final isMoving = vehicle['isMoving'] ?? false;

      if (lat == null || lng == null) continue;

      final pos = LatLng(lat.toDouble(), lng.toDouble());
      // Utilisez _marrakechZone pour déterminer la couleur du marqueur
      final inZone = GeoUtils.isPointInPolygon(pos, _marrakechZone);

      updatedMarkers[plate] = Marker(
        point: pos,
        width: 80,
        height: 80,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedVehicleDetails = {
                'plate': plate,
                'latitude': lat.toStringAsFixed(6),
                'longitude': lng.toStringAsFixed(6),
                'speed': '$speed km/h',
                'status': isMoving ? 'En mouvement' : 'Arrêté',
                'inZone': inZone ? 'Dans zone' : 'Hors zone', // Affiche l'état par rapport à la zone de Marrakech
              };
            });
          },
          child: Icon(
            Icons.directions_car,
            color: inZone ? Colors.green : Colors.red, // La couleur dépendra de la présence dans _marrakechZone
            size: 30,
          ),
        ),
      );
    }

    if (mounted) setState(() => _markers = updatedMarkers);
  }

  void _startSSE() {
    final request = http.Request('GET', Uri.parse('$_apiBaseUrl/api/stream/locations'))
      ..headers['Accept'] = 'text/event-stream';

    final client = http.Client();
    client.send(request).then((response) {
      if (response.statusCode == 200) {
        _sseSubscription = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
          if (line.startsWith('data: ')) {
            try {
              final data = jsonDecode(line.substring(6));
              if (data['success'] == true) {
                _updateMarkers(data['data']);
              }
            } catch (e) {
              debugPrint('Erreur parsing SSE: $e');
            }
          }
        }, onError: (error) {
          debugPrint('Erreur dans le stream SSE: $error');
          _sseSubscription?.cancel();
          Future.delayed(const Duration(seconds: 5), _startSSE); // Tente de se reconnecter
        }, onDone: () {
          debugPrint('SSE Stream terminé.');
          _sseSubscription?.cancel();
          Future.delayed(const Duration(seconds: 5), _startSSE); // Tente de se reconnecter
        });
      } else {
        debugPrint('Erreur de connexion SSE: ${response.statusCode}');
        _showError('Erreur de connexion aux événements en direct.');
      }
    }).catchError((e) {
      debugPrint('Erreur de connexion SSE (catchError): $e');
      _showError('Erreur de connexion aux événements en direct.');
      Future.delayed(const Duration(seconds: 5), _startSSE); // Tente de se reconnecter
    });
  }

  void _startAlertChecking() {
    _alertCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkForAlerts();
    });
  }

  Future<void> _checkForAlerts() async {
    try {
      final response = await http.get(Uri.parse('$_apiBaseUrl/api/alerts'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          debugPrint('Alertes reçues du backend: ${data['data']}');
          for (var alert in data['data']) {
            final message = alert['message'];
            // Afficher la notification SnackBar
            _showAlertNotification(message);
            // Sauvegarder l'alerte dans Firebase
            _saveAlertToFirebase(alert); // NOUVEAU : Sauvegarde l'alerte
          }
        }
      }
    } catch (e) {
      debugPrint('Erreur check alert: $e');
      // Optionnel: _showError('Erreur lors de la vérification des alertes.');
    }
  }

  // NOUVELLE FONCTION : Sauvegarde les alertes dans Firebase Firestore
  Future<void> _saveAlertToFirebase(Map<String, dynamic> alertData) async {
    try {
      await FirebaseFirestore.instance.collection('alerts').add({
        'plate': alertData['plate'],
        'message': alertData['message'],
        // Convertir la chaîne ISO timestamp du backend en objet Timestamp de Firebase
        'timestamp': Timestamp.fromDate(DateTime.parse(alertData['timestamp'])),
        'location': {
          'latitude': alertData['location']['latitude'],
          'longitude': alertData['location']['longitude'],
        },
        'createdAt': FieldValue.serverTimestamp(), // Pour le tri et l'horodatage côté serveur
      });
      debugPrint('Alerte sauvegardée dans Firebase: ${alertData['message']}');
    } catch (e) {
      debugPrint('Erreur lors de la sauvegarde de l\'alerte dans Firebase: $e');
      _showError('Erreur lors de la sauvegarde d\'une alerte.');
    }
  }

  void _showAlertNotification(String message) {
    if (mounted) { // Vérifie que le widget est toujours dans l'arbre
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } else {
      debugPrint('Tente d\'afficher une notification mais le widget n\'est pas monté : $message');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError('Les services de localisation sont désactivés.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError('Permission de localisation refusée.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showError('Permission refusée définitivement.');
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        _mapController.camera.zoom,
      );
    } catch (e) {
      _showError('Erreur localisation : $e');
    }
  }

  @override
  void dispose() {
    _sseSubscription?.cancel();
    _alertCheckTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Survi Admin - Marrakech'),
        backgroundColor: Colors.grey[850],
        elevation: 0,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(31.6295, -7.9811),
              initialZoom: 11.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              PolygonLayer(
                polygons: [
                  // Utiliser _marrakechZone pour l'affichage de la zone
                  Polygon(
                    points: _marrakechZone,
                    color: Colors.blue.withOpacity(0.2),
                    borderStrokeWidth: 2,
                    borderColor: Colors.blue,
                  ),
                ],
              ),
              MarkerLayer(
                markers: _markers.values.toList(),
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 120,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'locateMe',
                  mini: true,
                  backgroundColor: Colors.grey[800],
                  onPressed: _getCurrentLocation,
                  child: const Icon(Icons.gps_fixed, color: Colors.white),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoomIn',
                  mini: true,
                  backgroundColor: Colors.grey[800],
                  onPressed: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom + 1,
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoomOut',
                  mini: true,
                  backgroundColor: Colors.grey[800],
                  onPressed: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom - 1,
                  ),
                  child: const Icon(Icons.remove, color: Colors.white),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedVehicleDetails != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedVehicleDetails!['plate'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _selectedVehicleDetails!['inZone'] == 'Dans zone'
                                ? Colors.green
                                : Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _selectedVehicleDetails!['inZone'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.speed, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          _selectedVehicleDetails!['speed'],
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.location_on, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${_selectedVehicleDetails!['latitude']}, ${_selectedVehicleDetails!['longitude']}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.directions_car, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          _selectedVehicleDetails!['status'],
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ] else ...[
                    const Text(
                      'Cliquez sur un véhicule pour voir ses détails',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // NOUVEL IMPORT POUR FIREBASE

class GeoUtils {
  static bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    double x = point.latitude;
    double y = point.longitude;
    bool inside = false;

    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].latitude;
      final yi = polygon[i].longitude;
      final xj = polygon[j].latitude;
      final yj = polygon[j].longitude;

      final intersect = ((yi > y) != (yj > y)) &&
          (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }
}

class AdminLiveTrackingPage extends StatefulWidget {
  const AdminLiveTrackingPage({super.key});

  @override
  State<AdminLiveTrackingPage> createState() => _AdminLiveTrackingPageState();
}

class _AdminLiveTrackingPageState extends State<AdminLiveTrackingPage> {
  final MapController _mapController = MapController();

  // Cette zone est maintenant la grande zone de Marrakech pour l'affichage et la logique d'alerte
  // Elle doit correspondre EXACTEMENT à MARRAKECH_ALERT_ZONE dans votre backend Node.js
  final List<LatLng> _marrakechZone = [
    const LatLng(31.670, -8.040),
    const LatLng(31.700, -7.950),
    const LatLng(31.630, -7.900),
    const LatLng(31.620, -7.880),
    const LatLng(31.580, -7.980),
    const LatLng(31.550, -8.050),
    const LatLng(31.600, -8.150),
    const LatLng(31.650, -8.100),
    const LatLng(31.670, -8.040), // Fermeture du polygone
  ];

  static const String _apiBaseUrl = 'http://10.0.2.2:3000';
  Map<String, Marker> _markers = {};
  StreamSubscription? _sseSubscription;
  Timer? _alertCheckTimer;
  Map<String, dynamic>? _selectedVehicleDetails;

  // REMOVED: final Set<String> _alertedPlates = {}; // Plus besoin de cette logique de dédoublonnage ici

  @override
  void initState() {
    super.initState();
    _fetchVehicles();
    _startSSE();
    _startAlertChecking(); // Démarrage du timer de vérification des alertes
  }

  Future<void> _fetchVehicles() async {
    try {
      final response = await http.get(Uri.parse('$_apiBaseUrl/api/vehicles'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _updateMarkers(data['data']);
        }
      }
    } catch (e) {
      _showError('Erreur de connexion lors de la récupération des véhicules.');
      debugPrint('Erreur fetchVehicles: $e'); // Pour le débogage
    }
  }

  void _updateMarkers(List<dynamic> vehicles) {
    final updatedMarkers = <String, Marker>{};

    for (var vehicle in vehicles) {
      final plate = vehicle['plate'] as String? ?? 'Inconnu';
      final lat = vehicle['location']?['latitude'];
      final lng = vehicle['location']?['longitude'];
      final speed = vehicle['speed']?.toStringAsFixed(1) ?? '0.0';
      final isMoving = vehicle['isMoving'] ?? false;

      if (lat == null || lng == null) continue;

      final pos = LatLng(lat.toDouble(), lng.toDouble());
      // Utilisez _marrakechZone pour déterminer la couleur du marqueur
      final inZone = GeoUtils.isPointInPolygon(pos, _marrakechZone);

      updatedMarkers[plate] = Marker(
        point: pos,
        width: 80,
        height: 80,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedVehicleDetails = {
                'plate': plate,
                'latitude': lat.toStringAsFixed(6),
                'longitude': lng.toStringAsFixed(6),
                'speed': '$speed km/h',
                'status': isMoving ? 'En mouvement' : 'Arrêté',
                'inZone': inZone ? 'Dans zone' : 'Hors zone', // Affiche l'état par rapport à la zone de Marrakech
              };
            });
          },
          child: Icon(
            Icons.directions_car,
            color: inZone ? Colors.green : Colors.red, // La couleur dépendra de la présence dans _marrakechZone
            size: 30,
          ),
        ),
      );
    }

    if (mounted) setState(() => _markers = updatedMarkers);
  }

  void _startSSE() {
    final request = http.Request('GET', Uri.parse('$_apiBaseUrl/api/stream/locations'))
      ..headers['Accept'] = 'text/event-stream';

    final client = http.Client();
    client.send(request).then((response) {
      if (response.statusCode == 200) {
        _sseSubscription = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
          if (line.startsWith('data: ')) {
            try {
              final data = jsonDecode(line.substring(6));
              if (data['success'] == true) {
                _updateMarkers(data['data']);
              }
            } catch (e) {
              debugPrint('Erreur parsing SSE: $e');
            }
          }
        }, onError: (error) {
          debugPrint('Erreur dans le stream SSE: $error');
          _sseSubscription?.cancel();
          Future.delayed(const Duration(seconds: 5), _startSSE); // Tente de se reconnecter
        }, onDone: () {
          debugPrint('SSE Stream terminé.');
          _sseSubscription?.cancel();
          Future.delayed(const Duration(seconds: 5), _startSSE); // Tente de se reconnecter
        });
      } else {
        debugPrint('Erreur de connexion SSE: ${response.statusCode}');
        _showError('Erreur de connexion aux événements en direct.');
      }
    }).catchError((e) {
      debugPrint('Erreur de connexion SSE (catchError): $e');
      _showError('Erreur de connexion aux événements en direct.');
      Future.delayed(const Duration(seconds: 5), _startSSE); // Tente de se reconnecter
    });
  }

  void _startAlertChecking() {
    _alertCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkForAlerts();
    });
  }

  Future<void> _checkForAlerts() async {
    try {
      final response = await http.get(Uri.parse('$_apiBaseUrl/api/alerts'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          debugPrint('Alertes reçues du backend: ${data['data']}');
          for (var alert in data['data']) {
            final message = alert['message'];
            // Afficher la notification SnackBar
            _showAlertNotification(message);
            // Sauvegarder l'alerte dans Firebase
            _saveAlertToFirebase(alert); // NOUVEAU : Sauvegarde l'alerte
          }
        }
      }
    } catch (e) {
      debugPrint('Erreur check alert: $e');
      // Optionnel: _showError('Erreur lors de la vérification des alertes.');
    }
  }

  // NOUVELLE FONCTION : Sauvegarde les alertes dans Firebase Firestore
  Future<void> _saveAlertToFirebase(Map<String, dynamic> alertData) async {
    try {
      await FirebaseFirestore.instance.collection('alerts').add({
        'plate': alertData['plate'],
        'message': alertData['message'],
        // Convertir la chaîne ISO timestamp du backend en objet Timestamp de Firebase
        'timestamp': Timestamp.fromDate(DateTime.parse(alertData['timestamp'])),
        'location': {
          'latitude': alertData['location']['latitude'],
          'longitude': alertData['location']['longitude'],
        },
        'createdAt': FieldValue.serverTimestamp(), // Pour le tri et l'horodatage côté serveur
      });
      debugPrint('Alerte sauvegardée dans Firebase: ${alertData['message']}');
    } catch (e) {
      debugPrint('Erreur lors de la sauvegarde de l\'alerte dans Firebase: $e');
      _showError('Erreur lors de la sauvegarde d\'une alerte.');
    }
  }

  void _showAlertNotification(String message) {
    if (mounted) { // Vérifie que le widget est toujours dans l'arbre
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } else {
      debugPrint('Tente d\'afficher une notification mais le widget n\'est pas monté : $message');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError('Les services de localisation sont désactivés.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError('Permission de localisation refusée.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showError('Permission refusée définitivement.');
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        _mapController.camera.zoom,
      );
    } catch (e) {
      _showError('Erreur localisation : $e');
    }
  }

  @override
  void dispose() {
    _sseSubscription?.cancel();
    _alertCheckTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Survi Admin - Marrakech'),
        backgroundColor: Colors.grey[850],
        elevation: 0,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(31.6295, -7.9811),
              initialZoom: 11.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              PolygonLayer(
                polygons: [
                  // Utiliser _marrakechZone pour l'affichage de la zone
                  Polygon(
                    points: _marrakechZone,
                    color: Colors.blue.withOpacity(0.2),
                    borderStrokeWidth: 2,
                    borderColor: Colors.blue,
                  ),
                ],
              ),
              MarkerLayer(markers: _markers.values.toList()),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 120,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'locateMe',
                  mini: true,
                  backgroundColor: Colors.grey[800],
                  onPressed: _getCurrentLocation,
                  child: const Icon(Icons.gps_fixed, color: Colors.white),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoomIn',
                  mini: true,
                  backgroundColor: Colors.grey[800],
                  onPressed: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom + 1,
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoomOut',
                  mini: true,
                  backgroundColor: Colors.grey[800],
                  onPressed: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom - 1,
                  ),
                  child: const Icon(Icons.remove, color: Colors.white),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedVehicleDetails != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedVehicleDetails!['plate'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _selectedVehicleDetails!['inZone'] == 'Dans zone'
                                ? Colors.green
                                : Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _selectedVehicleDetails!['inZone'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.speed, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          _selectedVehicleDetails!['speed'],
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.location_on, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${_selectedVehicleDetails!['latitude']}, ${_selectedVehicleDetails!['longitude']}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.directions_car, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          _selectedVehicleDetails!['status'],
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ] else ...[
                    const Text(
                      'Cliquez sur un véhicule pour voir ses détails',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
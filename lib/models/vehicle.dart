import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart'; // CHANGÉ : Importez LatLng de latlong2 pour flutter_map

class Vehicle {
  final String id;
  final String model;
  final String licensePlate;
  final bool isAvailable;
  final bool isBlocked;
  final LatLng? homeLocation; // Utilise LatLng de latlong2
  final String? imageUrl;
  final Timestamp? timestamp; // Ajout pour suivre la date d'ajout/mise à jour

  Vehicle({
    required this.id,
    required this.model,
    required this.licensePlate,
    this.isAvailable = true,
    this.isBlocked = false,
    this.homeLocation,
    this.imageUrl,
    this.timestamp, // Optionnel, défini par Firestore
  });

  factory Vehicle.fromMap(Map<String, dynamic> data, String id) {
    return Vehicle(
      id: id,
      model: data['model'] as String? ?? '',
      licensePlate: data['licensePlate'] as String? ?? '',
      isAvailable: data['isAvailable'] as bool? ?? true,
      isBlocked: data['isBlocked'] as bool? ?? false,
      homeLocation: data['homeLocation'] != null
          ? LatLng(
        (data['homeLocation']['lat'] as num?)?.toDouble() ?? 0.0,
        (data['homeLocation']['lng'] as num?)?.toDouble() ?? 0.0,
      )
          : null, // Conversion de la map Firestore en LatLng
      imageUrl: data['imageUrl'] as String?,
      timestamp: data['timestamp'] as Timestamp?, // Récupération du timestamp
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'model': model,
      'licensePlate': licensePlate,
      'isAvailable': isAvailable,
      'isBlocked': isBlocked,
      'homeLocation': homeLocation != null
      // Utilisation de l'opérateur '!' car homeLocation est vérifié non-null
          ? {'lat': homeLocation!.latitude, 'lng': homeLocation!.longitude}
          : null, // Conversion de LatLng en map pour Firestore
      'imageUrl': imageUrl,
      'timestamp': timestamp, // Inclure le timestamp dans la map
    };
  }

  Vehicle copyWith({
    String? id,
    String? model,
    String? licensePlate,
    bool? isAvailable,
    bool? isBlocked,
    LatLng? homeLocation,
    String? imageUrl,
    Timestamp? timestamp,
  }) {
    return Vehicle(
      id: id ?? this.id,
      model: model ?? this.model,
      licensePlate: licensePlate ?? this.licensePlate,
      isAvailable: isAvailable ?? this.isAvailable,
      isBlocked: isBlocked ?? this.isBlocked,
      homeLocation: homeLocation ?? this.homeLocation,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
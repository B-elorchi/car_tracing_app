import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Ajout pour debugPrint et Uint8List
import 'package:latlong2/latlong.dart'; // CHANGÉ : Importez LatLng de latlong2 pour flutter_map
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io'; // Importation de la classe File pour la lecture de fichiers

import '../models/vehicle.dart'; // Assurez-vous que le chemin est correct

// FILE NAMING CONVENTION:
// Renommez ce fichier de 'VehicleController.dart' en 'vehicle_controller.dart'
// Les bonnes pratiques Dart recommandent lower_case_with_underscores pour les noms de fichiers.

class VehicleController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'vehicles';
  final SupabaseClient _supabase = Supabase.instance.client; // Instance Supabase

  // MODIFIÉ : Ajout d'un véhicule - maintenant utilise licensePlate comme ID de document
  Future<void> addVehicle({
    required String model,
    required String licensePlate, // Cette plaque sera l'ID du document Firestore
    required bool isAvailable,
    required String imageUrl, // URL de l'image uploadée sur Supabase
    LatLng? homeLocation, // Optionnel pour stocker la localisation initiale
  }) async {
    try {
      // Utilisez doc(licensePlate).set() pour définir l'ID du document
      await _firestore.collection(_collectionName).doc(licensePlate).set({
        'model': model,
        'licensePlate': licensePlate,
        'isAvailable': isAvailable,
        'imageUrl': imageUrl, // Stockage de l'URL Supabase
        'isBlocked': false, // Par défaut, un nouveau véhicule n'est pas bloqué
        'homeLocation': homeLocation != null
            ? {'lat': homeLocation.latitude, 'lng': homeLocation.longitude}
            : null,
        'timestamp': FieldValue.serverTimestamp(), // Ajoute un timestamp de création/mise à jour
      });
    } catch (e) {
      debugPrint('Erreur lors de l\'ajout du véhicule : $e');
      throw Exception('Échec de l\'ajout du véhicule : $e');
    }
  }

  Stream<List<Vehicle>> getAllVehicles() {
    return _firestore
        .collection(_collectionName)
        .orderBy('timestamp', descending: true) // Trie par date de création/mise à jour
        .snapshots()
        .handleError((error) {
      debugPrint('Erreur lors de la récupération des véhicules : $error');
    })
        .map((snapshot) => snapshot.docs
        .map((doc) => Vehicle.fromMap(doc.data()!, doc.id)) // doc.id sera l'immatriculation
        .toList());
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    try {
      // Mettre à jour avec l'ID existant (qui est l'immatriculation)
      await _firestore
          .collection(_collectionName)
          .doc(vehicle.id) // vehicle.id est l'immatriculation
          .update(vehicle.toMap());
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour du véhicule : $e');
      throw Exception('Échec de la mise à jour du véhicule : $e');
    }
  }

  Future<void> deleteVehicle(String vehicleId) async {
    try {
      await _firestore.collection(_collectionName).doc(vehicleId).delete();
    } catch (e) {
      debugPrint('Erreur lors de la suppression du véhicule : $e');
      throw Exception('Échec de la suppression du véhicule : $e');
    }
  }

  Future<Vehicle?> getVehicleById(String vehicleId) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(vehicleId).get();
      if (doc.exists) {
        return Vehicle.fromMap(doc.data()!, doc.id);
      } else {
        return null; // Retourne null si le véhicule n'est pas trouvé
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération du véhicule par ID : $e');
      throw Exception('Échec de la récupération du véhicule : $e');
    }
  }

  Future<void> blockVehicle(String vehicleId) async {
    try {
      await _firestore.collection(_collectionName).doc(vehicleId).update({
        'isAvailable': false,
        'isBlocked': true,
      });
    } catch (e) {
      debugPrint('Erreur lors du blocage du véhicule : $e');
      throw Exception('Échec du blocage du véhicule : $e');
    }
  }

  Future<void> unblockVehicle(String vehicleId) async {
    try {
      await _firestore.collection(_collectionName).doc(vehicleId).update({
        'isAvailable': true,
        'isBlocked': false,
      });
    } catch (e) {
      debugPrint('Erreur lors du déblocage du véhicule : $e');
      throw Exception('Échec du déblocage du véhicule : $e');
    }
  }

  Future<void> toggleBlockStatus(String vehicleId, bool newBlockStatus) async {
    try {
      await _firestore.collection(_collectionName).doc(vehicleId).update({
        'isBlocked': newBlockStatus,
        'isAvailable': !newBlockStatus, // Synchronisation logique : bloqué = indisponible
      });
    } catch (e) {
      debugPrint('Erreur lors du changement de statut de blocage : $e');
      throw Exception('Échec du changement de statut de blocage : $e');
    }
  }

  Future<String> uploadImage(String filePath) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${filePath.split('/').last}';
      final Uint8List fileBytes = await File(filePath).readAsBytes();

      await _supabase.storage
          .from('vehicles')
          .uploadBinary(
        fileName,
        fileBytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );

      return _supabase.storage.from('vehicles').getPublicUrl(fileName);
    } on StorageException catch (e) {
      debugPrint('Erreur de stockage Supabase lors de l\'upload de l\'image: ${e.message}');
      throw Exception('Échec de l\'upload de l\'image vers Supabase: ${e.message}');
    } catch (e) {
      debugPrint('Erreur inattendue lors de l\'upload de l\'image : $e');
      throw Exception('Erreur inattendue lors de l\'upload de l\'image : $e');
    }
  }
}
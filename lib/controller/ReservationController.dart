// lib/controllers/ReservationController.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reservation.dart';

class ReservationController {
  final _firestore = FirebaseFirestore.instance;

  Future<String> createReservation({
    required String userId,
    required String vehicleId,
    required DateTime startTime,
    required DateTime endTime,
    required double amount, required String status,

  }) async {
    try {
      final docRef = await _firestore.collection('reservations').add({
        'userId': userId,
        'vehicleId': vehicleId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'status': 'pending',
        'amount': amount,
        'timestamp': FieldValue.serverTimestamp(),

      });
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create reservation: $e');
    }
  }

  Stream<List<Reservation>> getReservationsByUser(String userId) {
    return _firestore
        .collection('reservations')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Reservation.fromMap(doc.data(), doc.id))
        .toList());
  }

  Stream<List<Reservation>> getAllReservations() {
    return _firestore
        .collection('reservations')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Reservation.fromMap(doc.data(), doc.id))
        .toList());
  }

  Future<void> updateReservation(Reservation reservation) async {
    try {
      await _firestore
          .collection('reservations')
          .doc(reservation.id)
          .update(reservation.toMap());
    } catch (e) {
      throw Exception('Failed to update reservation: $e');
    }
  }

  Future<void> updateReservationStatus(String reservationId, String newStatus) async {
    try {
      // Accéder à la collection et au document spécifique, puis mettre à jour le champ 'status'
      await _firestore
          .collection('reservation') // Utiliser la constante pour le nom de collection
          .doc(reservationId) // Référence au document par son ID
          .update({'status': newStatus}); // Mettre à jour le champ 'status' avec la nouvelle valeur

      print('Reservation $reservationId status updated to "$newStatus"'); // Log de succès
    } catch (e) {
      print('Error updating reservation status $reservationId: $e'); // Log de l'erreur
      // Relancer l'exception pour que l'appelant puisse la gérer (ex: afficher un message à l'utilisateur)
      throw Exception('Échec de la mise à jour du statut de la réservation: ${e.toString()}');
    }
  }



  Future<void> deleteReservation(String reservationId) async {
    try {
      await _firestore.collection('reservations').doc(reservationId).delete();
    } catch (e) {
      throw Exception('Failed to delete reservation: $e');
    }
  }
}
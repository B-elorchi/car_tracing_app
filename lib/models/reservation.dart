// lib/models/reservation.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Reservation {
  final String id;
  final String userId;
  final String vehicleId;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final double amount; // In USD

  //constructeur

  Reservation({
    required this.id,
    required this.userId,
    required this.vehicleId,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.amount,
  });
//Fonction factory pour créer une Reservation à partir d’un Map (venant de Firestore).

  factory Reservation.fromMap(Map<String, dynamic> map, String id) {
    return Reservation(
      id: id,
      userId: map['userId'] ?? '',
      vehicleId: map['vehicleId'] ?? '',
      startTime: DateTime.parse(map['startTime'] ?? DateTime.now().toIso8601String()),
      endTime: DateTime.parse(map['endTime'] ?? DateTime.now().toIso8601String()),
      status: map['status'] ?? 'pending',
      amount: (map['amount'] ?? 0.0).toDouble(),
    );
  }
//Conversion vers Map (pour envoyer à Firestore)
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'vehicleId': vehicleId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'status': status,
      'amount': amount,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
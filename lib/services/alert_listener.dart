import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart'; // Ajouté pour debugPrint

// Le plugin de notifications est déjà défini globalement dans main.dart,
// mais il est bon de l'importer et de le réutiliser si ce fichier est séparé.
// Pour s'assurer qu'il s'agit bien de la même instance globale, on le passe si nécessaire,
// ou on s'assure qu'il est accessible via un singleton ou une méthode statique si le code est complexe.
// Pour ce cas, comme il est "final", il est probable qu'il soit globalement accessible.
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin(); // Répété pour l'autocomplétion, mais c'est l'instance globale de main.dart

class AlertListenerService {
  static String? lastAlertId;

  static void startListening() {
    FirebaseFirestore.instance
        .collection('alerts')
        .orderBy('createdAt', descending: true)
        .limit(1) // Écoute la dernière alerte
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final alert = snapshot.docs.first;
        final data = alert.data();

        debugPrint('Nouvelle alerte Firestore détectée: ${alert.id}'); // Pour le débogage

        // Ne montrer la notification que si c'est une nouvelle alerte (pas la même que la précédente)
        if (alert.id != lastAlertId) {
          lastAlertId = alert.id;

          _showLocalNotification(
            title: '🚨 Alerte véhicule',
            body:
            '${data['message'] ?? 'Alerte inconnue'}\nPlaque : ${data['plate'] ?? 'N/A'}',
          );
        } else {
          debugPrint('Alerte ${alert.id} déjà traitée.'); // Pour le débogage
        }
      }
    }, onError: (error) {
      debugPrint('Erreur lors de l\'écoute des alertes: $error');
    });
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    // Les détails du canal doivent correspondre au canal créé dans main.dart
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'alerts_channel', // DOIT CORRESPONDRE à l'ID du canal dans main.dart
      'Alertes Véhicules', // Nom du canal visible par l'utilisateur
      channelDescription: 'Notifications visibles des alertes', // Description du canal
      importance: Importance.max, // Niveau d'importance élevé
      priority: Priority.high, // Priorité haute
      playSound: true,
      enableVibration: true,
      ticker: 'Alerte véhicule', // Texte qui s'affiche brièvement dans la barre de statut
      // Autres options comme largeIcon, sound, etc.
    );

    const NotificationDetails notifDetails =
    NotificationDetails(android: androidDetails);

    // Afficher la notification
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // ID unique pour la notification
      title,
      body,
      notifDetails,
      // payload: 'some_payload_data', // Optionnel: Données à passer si l'utilisateur tape sur la notification
    );
    debugPrint('Notification affichée: $title - $body'); // Pour le débogage
  }
}
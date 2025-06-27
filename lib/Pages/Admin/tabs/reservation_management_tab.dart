// lib/pages/admin/tabs/reservation_management_tab.dart
import 'package:flutter/material.dart';
import 'package:projectkhadija/controller/ReservationController.dart'; // Ajustez le chemin
import 'package:projectkhadija/controller/VehicleController.dart'; // Ajustez le chemin
import 'package:projectkhadija/Auth/auth.dart'; // Ajustez le chemin
import 'package:projectkhadija/models/reservation.dart';
import 'package:projectkhadija/models/vehicle.dart';

class ReservationManagementTab extends StatelessWidget {
  final ReservationController reservationController;
  final VehicleController vehicleController;
  final AuthService authService;

  const ReservationManagementTab({
    Key? key,
    required this.reservationController,
    required this.vehicleController,
    required this.authService,
  }) : super(key: key);

  Future<(String, String)> _fetchVehicleAndUserName(String vehicleId, String userId) async {
    final vehicleFuture = vehicleController.getVehicleById(vehicleId);
    final userFuture = authService.getUserName(userId);

    final results = await Future.wait([
      vehicleFuture,
      userFuture,
    ]);

    final vehicle = results[0] as Vehicle?;
    final userName = results[1] as String?;

    final vehicleName = vehicle?.model ?? 'Véhicule Inconnu';
    final fetchedUserName = userName ?? 'Utilisateur Inconnu';

    return (vehicleName, fetchedUserName);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reservation>>(
      stream: reservationController.getAllReservations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          print('Stream error: ${snapshot.error}'); // Pour le debug
          return Center(child: Text('Erreur de chargement des réservations: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Aucune réservation trouvée.'));
        }
        else {
          final reservations = snapshot.data!;
          return ListView.builder(
            itemCount: reservations.length,
            itemBuilder: (context, index) {
              final reservation = reservations[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                elevation: 1.5,
                child: ListTile(
                  title: FutureBuilder<(String, String)>(
                    future: _fetchVehicleAndUserName(reservation.vehicleId, reservation.userId),
                    builder: (context, combinedSnapshot) {
                      if (combinedSnapshot.connectionState == ConnectionState.waiting) {
                        return const Text('Chargement des détails...');
                      } else if (combinedSnapshot.hasError || !combinedSnapshot.hasData) {
                        print('Error fetching combined data for reservation ${reservation.id}: ${combinedSnapshot.error}'); // Pour le debug
                        return Text('Véhicule ID: ${reservation.vehicleId}, Utilisateur ID: ${reservation.userId} (Erreur de chargement)');
                      } else {
                        final (vehicleName, userName) = combinedSnapshot.data!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Véhicule: $vehicleName', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('Utilisateur: $userName'),
                          ],
                        );
                      }
                    },
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Début: ${reservation.startTime.toLocal().toString().split(' ')[0]}'),
                      Text('Fin: ${reservation.endTime.toLocal().toString().split(' ')[0]}'),
                      Text(
                        'Statut: ${reservation.status}',
                        style: TextStyle(
                          color: reservation.status == 'completed' ? Colors.green :
                          reservation.status == 'pending' ? Colors.orange :
                          Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text('Montant: ${reservation.amount.toStringAsFixed(2)} \$'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                            reservation.status == 'pending' ? Icons.check_circle_outline : Icons.access_time,
                            color: reservation.status == 'pending' ? Colors.green : Colors.blueGrey
                        ),
                        tooltip: reservation.status == 'pending' ? 'Marquer comme terminée' : 'Marquer comme en attente',
                        onPressed: () async {
                          try {
                            await reservationController.updateReservation(
                              Reservation(
                                id: reservation.id,
                                userId: reservation.userId,
                                vehicleId: reservation.vehicleId,
                                startTime: reservation.startTime,
                                endTime: reservation.endTime,
                                status: reservation.status == 'pending' ? 'completed' : 'pending',
                                amount: reservation.amount,
                              ),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Statut de réservation mis à jour en "${reservation.status == 'pending' ? 'completed' : 'pending'}".')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erreur de mise à jour: ${e.toString()}')),
                              );
                            }
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Supprimer la réservation',
                        onPressed: () async {
                          final bool confirm = await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Confirmer la suppression'),
                                content: const Text('Voulez-vous vraiment supprimer cette réservation ?'),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Annuler'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('Supprimer'),
                                  ),
                                ],
                              );
                            },
                          ) ?? false;

                          if (confirm) {
                            try {
                              await reservationController.deleteReservation(reservation.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Réservation supprimée.')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erreur de suppression: ${e.toString()}')),
                                );
                              }
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }
      },
    );
  }
}
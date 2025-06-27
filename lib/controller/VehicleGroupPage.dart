import 'package:flutter/material.dart';
// CHEMIN ET NOM DE FICHIER CORRIGÉS (assurez-vous d'avoir renommé vehicle_controller.dart)
import 'package:projectkhadija/models/vehicle.dart';

import 'VehicleController.dart';

// FILE NAMING CONVENTION:
// Renommez ce fichier de 'VehicleGroupPage.dart' en 'vehicle_group_page.dart'
// Les bonnes pratiques Dart recommandent lower_case_with_underscores pour les noms de fichiers.

class VehicleGroupPage extends StatelessWidget {
  final VehicleController vehicleController;
  // CORRECTION: Utilisation de 'super.key'
  const VehicleGroupPage({super.key, required this.vehicleController});

  // Méthode pour basculer le statut de blocage
  void _toggleBlockStatus(BuildContext context, String vehicleId, bool currentBlockStatus) async {
    try {
      await vehicleController.toggleBlockStatus(vehicleId, !currentBlockStatus);
      // CORRECTION: Vérifier si le widget est toujours monté avant d'utiliser context
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Statut de blocage mis à jour avec succès')),
      );
    } catch (e) {
      // CORRECTION: Vérifier si le widget est toujours monté avant d'utiliser context
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groupes de Véhicules'),
        backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder<List<Vehicle>>(
        stream: vehicleController.getAllVehicles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erreur de chargement des véhicules: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucun véhicule trouvé.'));
          } else {
            final vehicles = snapshot.data!;
            // Groupement par modèle (exemple de logique de groupe)
            final vehiclesByModel = <String, List<Vehicle>>{};
            for (var vehicle in vehicles) {
              vehiclesByModel.putIfAbsent(vehicle.model, () => []).add(vehicle);
            }

            return ListView.builder(
              itemCount: vehiclesByModel.length,
              itemBuilder: (context, index) {
                final model = vehiclesByModel.keys.elementAt(index);
                final groupVehicles = vehiclesByModel[model]!;
                return ExpansionTile(
                  title: Text(model, style: const TextStyle(fontWeight: FontWeight.bold)),
                  children: groupVehicles.map((vehicle) {
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      elevation: 2.0,
                      child: ListTile(
                        leading: Icon(
                          vehicle.isBlocked ? Icons.block : Icons.directions_car,
                          color: vehicle.isBlocked ? Colors.red : Theme.of(context).primaryColor,
                        ),
                        title: Text(vehicle.licensePlate),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Statut: ${vehicle.isAvailable ? "Disponible" : "Indisponible"}'),
                            Text('Bloqué: ${vehicle.isBlocked ? "Oui" : "Non"}'),
                            if (vehicle.homeLocation != null)
                              Text(
                                'Localisation: Lat ${vehicle.homeLocation!.latitude.toStringAsFixed(4)}, Lng ${vehicle.homeLocation!.longitude.toStringAsFixed(4)}',
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            vehicle.isBlocked ? Icons.lock_open : Icons.lock,
                            color: vehicle.isBlocked ? Colors.green : Colors.red,
                          ),
                          onPressed: () => _toggleBlockStatus(context, vehicle.id, vehicle.isBlocked),
                        ),
                        onTap: () {
                          // CORRECTION: Vérifier si le widget est toujours monté avant d'utiliser context
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Détails du véhicule ${vehicle.licensePlate}')),
                          );
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            );
          }
        },
      ),
    );
  }
}
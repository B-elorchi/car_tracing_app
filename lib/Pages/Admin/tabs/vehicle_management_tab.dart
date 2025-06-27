import 'package:flutter/material.dart';
import 'package:projectkhadija/models/vehicle.dart';

import '../../../controller/VehicleController.dart';

class VehicleManagementTab extends StatelessWidget {
  final VehicleController vehicleController;

  const VehicleManagementTab({Key? key, required this.vehicleController}) : super(key: key);

  // Méthode pour naviguer vers une page d'édition (à implémenter séparément)
  void _navigateToEditVehicle(BuildContext context, Vehicle vehicle) {
    // TODO: Implémenter une page d'édition (ex. EditVehicleScreen)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Édition de "${vehicle.model}" à implémenter.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Vehicle>>(
        stream: vehicleController.getAllVehicles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            print('Stream error: ${snapshot.error}');
            return Center(child: Text('Erreur de chargement des véhicules: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucun véhicule trouvé. Cliquez sur le "+" pour en ajouter un !'));
          } else {
            final vehicles = snapshot.data!;
            return ListView.builder(
              itemCount: vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = vehicles[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  elevation: 2.0,
                  child: ListTile(
                    leading: vehicle.isBlocked
                        ? Icon(
                      Icons.block,
                      color: Colors.red.shade700,
                      size: 40,
                    )
                        : (vehicle.imageUrl?.isNotEmpty ?? false)
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.network(
                        vehicle.imageUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.directions_car,
                            color: Theme.of(context).primaryColor,
                            size: 40,
                          );
                        },
                      ),
                    )
                        : Icon(
                      Icons.directions_car,
                      color: Theme.of(context).primaryColor,
                      size: 40,
                    ),
                    title: Text(vehicle.model, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Plaque: ${vehicle.licensePlate}'),
                        Text(
                          vehicle.isAvailable ? 'Disponible' : 'Indisponible',
                          style: TextStyle(
                            color: vehicle.isAvailable ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Bloqué par Admin: ${vehicle.isBlocked ? 'Oui' : 'Non'}',
                          style: TextStyle(
                            color: vehicle.isBlocked ? Colors.red.shade700 : Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (vehicle.homeLocation != null)
                          Text(
                            'Zone Domicile: Lat ${vehicle.homeLocation!.latitude.toStringAsFixed(2)}, Lng ${vehicle.homeLocation!.longitude.toStringAsFixed(2)}',
                          ),
                        if (vehicle.timestamp != null)
                          Text(
                            'Dernière mise à jour: ${vehicle.timestamp!.toDate().toLocal().toString().split('.')[0]}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            vehicle.isBlocked ? Icons.lock_open : Icons.lock,
                            color: vehicle.isBlocked ? Colors.green : Colors.red,
                            size: 24,
                          ),
                          tooltip: vehicle.isBlocked ? 'Débloquer le véhicule' : 'Bloquer le véhicule',
                          onPressed: () async {
                            if (!context.mounted) return;
                            try {
                              await vehicleController.toggleBlockStatus(vehicle.id, !vehicle.isBlocked);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erreur de mise à jour du statut de blocage: ${e.toString()}')),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            vehicle.isAvailable ? Icons.event_available : Icons.event_busy,
                            color: vehicle.isAvailable ? Colors.green : Colors.redAccent,
                            size: 24,
                          ),
                          tooltip: vehicle.isAvailable ? 'Marquer comme indisponible' : 'Marquer comme disponible',
                          onPressed: () async {
                            if (!context.mounted) return;
                            if (vehicle.isBlocked && !vehicle.isAvailable) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Débloquez le véhicule pour le rendre disponible.')),
                              );
                              return;
                            }
                            try {
                              await vehicleController.updateVehicle(
                                vehicle.copyWith(isAvailable: !vehicle.isAvailable),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erreur de mise à jour: ${e.toString()}')),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue, size: 24),
                          tooltip: 'Éditer le véhicule',
                          onPressed: () => _navigateToEditVehicle(context, vehicle),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 24),
                          tooltip: 'Supprimer le véhicule',
                          onPressed: () async {
                            if (!context.mounted) return;
                            final bool confirm = await showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Confirmer la suppression'),
                                  content: Text('Voulez-vous vraiment supprimer le véhicule "${vehicle.model}" ?'),
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
                                await vehicleController.deleteVehicle(vehicle.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Véhicule "${vehicle.model}" supprimé.')),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erreur de suppression: ${e.toString()}')),
                                );
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
      ),
    );
  }
}
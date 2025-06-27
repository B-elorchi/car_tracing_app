import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Utile si GeoPoint est dans votre modèle
import 'package:projectkhadija/controller/ReservationController.dart'; // Chemin principal pour ReservationController
import 'package:projectkhadija/controller/VehicleController.dart'; // Chemin principal pour VehicleController
import 'package:projectkhadija/models/reservation.dart';
import 'package:projectkhadija/models/vehicle.dart';

import 'package:projectkhadija/Auth/auth.dart'; // Chemin principal pour AuthService


// Convert ManagerDashboard to a StatefulWidget to manage the selected tab index
class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({Key? key}) : super(key: key);

  @override
  _ManagerDashboardState createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  int _selectedIndex = 0; // State variable to track the selected tab index

  final Color primaryColor = Colors.deepPurple; // Example color

  // Instances des contrôleurs, initialisées une seule fois ici
  final VehicleController _vehicleController = VehicleController();
  final ReservationController _reservationController = ReservationController();
  final AuthService _authService = AuthService(); // Instance de AuthService

  late final List<Widget> _tabs; // Sera initialisé dans initState

  @override
  void initState() {
    super.initState();
    // Initialisation des onglets en passant les contrôleurs nécessaires
    _tabs = [
      ManagerVehicleTab(vehicleController: _vehicleController, primaryColor: primaryColor), // Passe le contrôleur et la couleur
      ManagerReservationTab(
        reservationController: _reservationController,
        vehicleController: _vehicleController, // Passe le VehicleController
        authService: _authService, // Passe le AuthService
        primaryColor: primaryColor, // Passe la couleur
      ),
    ];
  }

  // Function called when a bottom navigation bar item is tapped
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Dashboard', style: TextStyle(color: Colors.white)), // White text for title
        backgroundColor: primaryColor, // Apply primary color
        elevation: 4.0, // Add shadow
      ),
      // Use IndexedStack to display the correct tab content based on _selectedIndex
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      // Add the BottomNavigationBar
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[ // Ajoutez const
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car), // Icon for Vehicles
            label: 'Véhicules', // Label for Vehicles
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined), // Icon for Reservations, matching Admin
            label: 'Réservations', // Label for Reservations
          ),
        ],
        currentIndex: _selectedIndex, // Link the selected index to the state variable
        selectedItemColor: primaryColor, // Color for the selected item
        unselectedItemColor: Colors.grey[600], // Color for unselected items
        backgroundColor: Colors.white, // Background color of the bar
        type: BottomNavigationBarType.fixed, // Fixed type for consistent layout
        onTap: _onItemTapped, // Call the function when an item is tapped
        elevation: 8.0, // Add a slight shadow
      ),
    );
  }
}

// Widget for the Vehicle Management Tab for Manager
class ManagerVehicleTab extends StatelessWidget {
  final VehicleController vehicleController; // Reçoit le contrôleur
  final Color primaryColor; // Reçoit la couleur principale

  const ManagerVehicleTab({Key? key, required this.vehicleController, required this.primaryColor}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column( // Arrange header and list vertically
      children: [
        // Header for Vehicles section (moved into the tab)
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 16.0, right: 16.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row( // Use a Row to place icon and text side-by-side
              children: [
                Icon(
                  Icons.directions_car, // Vehicle icon
                  color: primaryColor, // Icon color matching the theme
                  size: 24.0, // Adjust icon size
                ),
                const SizedBox(width: 8.0), // Space between icon and text
                Text(
                  'Gestion des Véhicules', // Section Title
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Vehicle List
        Expanded( // Ensure the list takes the remaining space
          child: StreamBuilder<List<Vehicle>>(
            stream: vehicleController.getAllVehicles(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                print('Vehicle stream error: ${snapshot.error}');
                return Center(child: Text('Erreur de chargement des véhicules: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Aucun véhicule trouvé.'));
              } else {
                final vehicles = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  itemCount: vehicles.length,
                  itemBuilder: (context, index) {
                    final vehicle = vehicles[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      elevation: 2.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6.0),
                            // MODIFICATION ICI: Utilisation de imageUrl et Image.network
                            child: vehicle.imageUrl != null && vehicle.imageUrl!.isNotEmpty
                                ? Image.network(
                              vehicle.imageUrl!,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                print('Error loading vehicle image from URL ${vehicle.imageUrl}: $error');
                                return Container(
                                  width: 70,
                                  height: 70,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                                );
                              },
                            )
                                : Container( // Fallback if no image URL
                              width: 70,
                              height: 70,
                              color: Colors.grey[300],
                              child: const Icon(Icons.directions_car, size: 40, color: Colors.grey), // Icône générique si pas d'image
                            ),
                          ),
                          title: Text(
                            vehicle.model,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.0
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4.0),
                              Text(
                                'Plaque: ${vehicle.licensePlate}',
                                style: TextStyle(fontSize: 13.0, color: Colors.grey[700]),
                              ),
                              const SizedBox(height: 4.0),
                              Text(
                                vehicle.isAvailable ? 'Disponible' : 'Indisponible',
                                style: TextStyle(
                                  color: vehicle.isAvailable ? Colors.green[700] : Colors.red[700],
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.0,
                                ),
                              ),
                            ],
                          ),
                          trailing: Icon(
                            vehicle.isAvailable ? Icons.check_circle_outline : Icons.cancel_outlined,
                            color: vehicle.isAvailable ? Colors.green : Colors.red,
                            size: 30,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
            },
          ),
        ),
      ],
    );
  }
}


// Widget for the Reservation Management Tab for Manager
class ManagerReservationTab extends StatelessWidget {
  final ReservationController reservationController;
  final VehicleController vehicleController; // Reçoit le VehicleController
  final AuthService authService; // Reçoit le AuthService
  final Color primaryColor; // Reçoit la couleur principale

  const ManagerReservationTab({
    Key? key,
    required this.reservationController,
    required this.vehicleController,
    required this.authService,
    required this.primaryColor,
  }) : super(key: key);

  // Helper function to format date (déjà présent)
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // Helper function to get French status text (déjà présent)
  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'completed':
        return 'Terminée';
      case 'cancelled':
        return 'Annulée';
      default:
        return status;
    }
  }

  // Helper function to get status color (déjà présent)
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange[700]!;
      case 'completed':
        return Colors.green[700]!;
      case 'cancelled':
        return Colors.red[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  // NOUVELLE FONCTION: Pour récupérer le nom du véhicule et de l'utilisateur en parallèle (déjà présent)
  Future<(String, String)> _fetchVehicleAndUserName(String vehicleId, String userId) async {
    // Exécute les deux futures en parallèle
    final results = await Future.wait([
      vehicleController.getVehicleById(vehicleId), // Récupère l'objet Vehicle
      authService.getUserName(userId), // Récupère le nom de l'utilisateur
    ]);

    final vehicle = results[0] as Vehicle?;
    final userName = results[1] as String?;

    final vehicleName = vehicle?.model ?? 'Véhicule Inconnu'; // Utilise le modèle ou un fallback
    final fetchedUserName = userName ?? 'Utilisateur Inconnu'; // Utilise le nom ou un fallback

    return (vehicleName, fetchedUserName); // Retourne un tuple de noms
  }

  @override
  Widget build(BuildContext context) {
    return Column( // Arrange header and list vertically
      children: [
        // Header for Reservations section (moved into the tab)
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 16.0, right: 16.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row( // Use a Row to place icon and text side-by-side
              children: [
                Icon(
                  Icons.calendar_month_outlined, // Reservation icon
                  color: primaryColor, // Icon color matching the theme
                  size: 24.0, // Adjust icon size
                ),
                const SizedBox(width: 8.0), // Space between icon and text
                Text(
                  'Gestion des Réservations', // Section Title
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Reservation List
        Expanded( // Ensure the list takes the remaining space
          child: StreamBuilder<List<Reservation>>(
            stream: reservationController.getAllReservations(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                print('Reservation stream error: ${snapshot.error}');
                return Center(child: Text('Erreur de chargement des réservations: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Aucune réservation trouvée.'));
              } else {
                final reservations = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  itemCount: reservations.length,
                  itemBuilder: (context, index) {
                    final reservation = reservations[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      elevation: 2.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                          // NOUVEAU: Utilisation de FutureBuilder pour charger les noms
                          title: FutureBuilder<(String, String)>(
                            future: _fetchVehicleAndUserName(reservation.vehicleId, reservation.userId),
                            builder: (context, combinedSnapshot) {
                              if (combinedSnapshot.connectionState == ConnectionState.waiting) {
                                return const Text(
                                    'Chargement des détails...',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0)
                                );
                              } else if (combinedSnapshot.hasError || !combinedSnapshot.hasData) {
                                print('Error fetching combined data for reservation ${reservation.id}: ${combinedSnapshot.error}');
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Réservation #${reservation.id.substring(0, 6)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0)),
                                    Text('Véhicule ID: ${reservation.vehicleId.substring(0, 6)}...', style: TextStyle(fontSize: 13.0, color: Colors.red[700])),
                                    Text('Utilisateur ID: ${reservation.userId.substring(0, 6)}...', style: TextStyle(fontSize: 13.0, color: Colors.red[700])),
                                  ],
                                ); // Fallback
                              } else {
                                final (vehicleName, userName) = combinedSnapshot.data!; // Récupère le tuple
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Réservation #${reservation.id.substring(0, 6)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0)),
                                    Text('Véhicule: $vehicleName', style: TextStyle(fontSize: 13.0, color: Colors.grey[800])),
                                    Text('Utilisateur: $userName', style: TextStyle(fontSize: 13.0, color: Colors.grey[800])),
                                  ],
                                );
                              }
                            },
                          ),
                          // FIN NOUVEAU
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4.0),
                              // Les lignes "Véhicule ID" et "Utilisateur ID" d'origine sont supprimées d'ici car elles sont maintenant dans le titre
                              Text(
                                  'Début: ${_formatDate(reservation.startTime)}', // Utilisation de _formatDate
                                  style: TextStyle(fontSize: 13.0, color: Colors.grey[700])
                              ),
                              Text(
                                  'Fin: ${_formatDate(reservation.endTime)}', // Utilisation de _formatDate
                                  style: TextStyle(fontSize: 13.0, color: Colors.grey[700])
                              ),
                              const SizedBox(height: 4.0),
                              Text('Montant: ${reservation.amount.toStringAsFixed(2)} €',
                                  style: const TextStyle(fontWeight: FontWeight.w600) // Ajout const
                              ),
                              const SizedBox(height: 4.0),
                              Text(
                                'Statut: ${_getStatusText(reservation.status)}',
                                style: TextStyle(
                                  color: _getStatusColor(reservation.status),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.0,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  reservation.status == 'pending' ? Icons.check_circle_outline : Icons.pending_actions_outlined,
                                  color: reservation.status == 'pending' ? Colors.green : Colors.orangeAccent,
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
                                        status: reservation.status == 'pending' ? 'completed' : 'pending', // Bascule simple
                                        amount: reservation.amount,
                                      ),
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Statut de réservation mis à jour.')),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Erreur de mise à jour: $e')),
                                      );
                                    }
                                  }
                                },
                              ),
                              // Bouton de suppression
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
                                          SnackBar(content: Text('Erreur de suppression: $e')),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
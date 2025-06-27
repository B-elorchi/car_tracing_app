import 'package:flutter/material.dart'; // Importation unique de material.dart
import 'package:projectkhadija/Pages/Admin/tabs/reservation_management_tab.dart';
import 'package:projectkhadija/Pages/Admin/tabs/vehicle_history_tab.dart';
import 'package:projectkhadija/Pages/Admin/tabs/vehicle_management_tab.dart';

import 'package:projectkhadija/controller/ReservationController.dart'; // Chemin corrigé
import 'package:projectkhadija/controller/VehicleController.dart'; // Chemin corrigé
import 'package:projectkhadija/Auth/auth.dart';
import 'package:projectkhadija/controller/AlertsPage.dart';
import 'package:projectkhadija/controller/VehicleGroupPage.dart';
import 'package:projectkhadija/controller/AddVehicleScreen.dart'; // Chemin corrigé
import 'package:projectkhadija/controller/AdminLiveTrackingPage.dart'; // Chemin corrigé

// Importations des onglets


// Enumération pour gérer les onglets
enum AdminDashboardTab {
  vehicleManagement,
  vehicleHistory,
  liveTracking,
  vehicleGroup,
  reservations,
  alerts,
}

// FILE NAMING CONVENTION:
// Renommez ce fichier de 'AdminDashboard.dart' en 'admin_dashboard.dart'
// Les bonnes pratiques Dart recommandent lower_case_with_underscores pour les noms de fichiers.

class AdminDashboard extends StatefulWidget {
  // CORRECTION: Utilisation de 'super.key' pour passer la clé
  const AdminDashboard({super.key});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  AdminDashboardTab _selectedTab = AdminDashboardTab.vehicleManagement;

  final VehicleController _vehicleController = VehicleController();
  final ReservationController _reservationController = ReservationController();
  final AuthService _authService = AuthService(); // Problème "argument type" ici.
  // Solution principale : Nettoyer le projet Flutter.
  // Exécutez dans votre terminal:
  // 1. flutter clean
  // 2. flutter pub get
  // 3. Relancez votre application.
  // Si l'erreur persiste, cela peut indiquer une configuration complexe où
  // AuthService est peut-être importé ou géré de manière non standard.

  late final List<Widget> _tabs;

  final Map<AdminDashboardTab, String> _tabTitles = {
    AdminDashboardTab.vehicleManagement: 'Tableau de bord',
    AdminDashboardTab.vehicleHistory: 'Historique Véhicules',
    AdminDashboardTab.liveTracking: 'Position',
    AdminDashboardTab.vehicleGroup: 'Groupe de véhicules',
    AdminDashboardTab.reservations: 'Réservations',
    AdminDashboardTab.alerts: 'Alertes',
  };

  @override
  void initState() {
    super.initState();
    _tabs = [
      VehicleManagementTab(vehicleController: _vehicleController),
      VehicleHistoryTab(vehicleController: _vehicleController),
      const AdminLiveTrackingPage(),
      ReservationManagementTab(
        // Problème \"argument type\" persiste ici.
        reservationController: _reservationController,
        vehicleController: _vehicleController,
        authService: _authService, // Le problème "argument type" persiste ici.
      ),
      const AlertsPage(),
    ];
  }

  void _onMenuItemTapped(AdminDashboardTab tab) {
    setState(() {
      _selectedTab = tab;
    });
    // CORRECTION: Vérifier si le widget est toujours monté avant d'utiliser context
    if (!context.mounted) return;
    Navigator.pop(context); // Ferme le Drawer
  }

  Future<void> _signOut() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Oui'),
          ),
        ],
      ),
    ) ?? false;

    // CORRECTION: Vérifier si le widget est toujours monté avant d'utiliser context
    if (shouldLogout && context.mounted) {
      await _authService.signOut();
      // CORRECTION: Vérifier à nouveau si le widget est monté avant de naviguer
      if (!context.mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabTitles[_selectedTab] ?? 'Admin Dashboard'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/images/lexus_track_logo.png',
                    height: 80,
                    width: 80,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.car_rental, size: 60, color: Colors.white);
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Connecté en tant que : Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Tableau de bord'),
              selected: _selectedTab == AdminDashboardTab.vehicleManagement,
              onTap: () => _onMenuItemTapped(AdminDashboardTab.vehicleManagement),
            ),
            ListTile(
              leading: const Icon(Icons.history_edu_outlined),
              title: const Text('Historique Véhicules'),
              selected: _selectedTab == AdminDashboardTab.vehicleHistory,
              onTap: () => _onMenuItemTapped(AdminDashboardTab.vehicleHistory),
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Position'),
              selected: _selectedTab == AdminDashboardTab.liveTracking,
              onTap: () => _onMenuItemTapped(AdminDashboardTab.liveTracking),
            ),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Groupe de véhicules'),
              selected: _selectedTab == AdminDashboardTab.vehicleGroup,
              onTap: () => _onMenuItemTapped(AdminDashboardTab.vehicleGroup),
            ),
            ListTile(
              leading: const Icon(Icons.event_note_outlined),
              title: const Text('Réservations'),
              selected: _selectedTab == AdminDashboardTab.reservations,
              onTap: () => _onMenuItemTapped(AdminDashboardTab.reservations),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active),
              title: const Text('Alertes'),
              selected: _selectedTab == AdminDashboardTab.alerts,
              onTap: () => _onMenuItemTapped(AdminDashboardTab.alerts),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
              onTap: _signOut,
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: IndexedStack(
            index: AdminDashboardTab.values.indexOf(_selectedTab),
            children: _tabs,
          ),
        ),
      ),
      floatingActionButton: _selectedTab == AdminDashboardTab.vehicleManagement
          ? FloatingActionButton(
        onPressed: () {
          // CORRECTION: Vérifier si le widget est toujours monté avant de naviguer
          if (!context.mounted) return;
          Navigator.push(
            context,
            // Assurez-vous que AddVehicleScreen.dart est renommé en add_vehicle_screen.dart
            MaterialPageRoute(builder: (context) => const AddVehicleScreen()),
          );
        },
        child: const Icon(Icons.add),
        tooltip: 'Ajouter un nouveau véhicule',
      )
          : null,
    );
  }
}
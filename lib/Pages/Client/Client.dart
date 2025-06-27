import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// NOTE: material as material est redondant, juste un import suffit
import 'package:flutter/material.dart' as material; // Ce n'est plus nécessaire
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:projectkhadija/Auth/auth.dart';
import 'package:projectkhadija/Pages/Client/EditProfilePage.dart';

// Assurez-vous que ces chemins d'importation sont corrects pour votre projet et en snake_case

import 'package:projectkhadija/models/reservation.dart';
import 'package:projectkhadija/models/vehicle.dart';


import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../controller/ReservationController.dart';
// CORRECTION: Correction du chemin d'importation
import '../../controller/VehicleController.dart';

// Define some constants for styling for easier maintenance
class AppConstants {
  static const double cardElevation = 4.0;
  static const double borderRadius = 12.0;
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
  static const EdgeInsets screenPadding = EdgeInsets.all(16.0);
}

// Renommez ce fichier de 'ClientDashboard.dart' en 'client_dashboard.dart'
class ClientDashboard extends StatefulWidget {
  const ClientDashboard({super.key});

  @override
  State<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard> {
  final VehicleController _vehicleController = VehicleController();
  final ReservationController _reservationController = ReservationController();
  final AuthService _authService = AuthService();

  // ATTENTION: La clé secrète de Stripe (sk_test_...) ne doit JAMAIS être stockée directement dans le code source
  // d'une application client (front-end) pour la production. Elle doit être utilisée uniquement
  // sur un serveur sécurisé (backend ou Cloud Function). Pour le développement, c'est toléré,
  // mais utilisez des variables d'environnement si possible (ex: flutter_dotenv).
  final String? _stripeSecretKey = dotenv.env['STRIPE_API_KEY'];

  String? _userId;
  String? _firstName;
  String? _lastName;
  String? _phoneNumber;
  String? _email;

  final double _pricePerDay = 50.0;
  Map<String, dynamic>? _paymentIntentData;
  int _selectedIndex = 0;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _loadUserData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.uid.isNotEmpty) {
      try {
        final fetchedFirstName = await _authService.getUserFirstName(user.uid);
        final fetchedLastName = await _authService.getUserLastName(user.uid);
        final fetchedPhoneNumber = await _authService.getUserPhoneNumber(user.uid);
        final fetchedEmail = user.email;

        if (mounted) {
          setState(() {
            _firstName = fetchedFirstName;
            _lastName = fetchedLastName;
            _phoneNumber = fetchedPhoneNumber;
            _email = fetchedEmail;
          });
        }
      } catch (e) {
        debugPrint("Erreur lors de la récupération des données utilisateur depuis Firestore: $e");
        if (mounted) {
          setState(() {
            _firstName = "Prénom non défini";
            _lastName = "Nom non défini";
            _phoneNumber = "Non défini";
            _email = user.email ?? "Email non disponible";
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _firstName = null;
          _lastName = null;
          _phoneNumber = null;
          _email = null;
        });
      }
    }
  }

  // AMÉLIORÉ : Gestion des images réseau (Supabase) et assets locaux avec feedback de chargement
  Widget _buildVehicleImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      debugPrint("Image URL is null or empty, showing placeholder.");
      return _buildPlaceholderImage();
    }
    // Vérifier si c'est une URL HTTP/HTTPS (Supabase)
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      debugPrint("Attempting to load network image from: $imageUrl"); // Ajouté pour le debugging
      return Image.network(
        imageUrl,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
          if (loadingProgress == null) {
            return child; // Image fully loaded, display it
          }
          // Image is still loading, show a progress indicator
          return Container(
            height: 180,
            width: double.infinity,
            color: Colors.grey[200], // Placeholder background
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null, // Shows an indeterminate progress if total bytes are unknown
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint("Error loading network image '$imageUrl': $error");
          // L'erreur précise s'affichera dans la console (ex: SocketException, HandshakeException)
          return _buildPlaceholderImage(error: true);
        },
      );
    }
    // Sinon, tenter de charger comme un asset local (pour la rétrocompatibilité ou si l'URL est un chemin d'asset)
    debugPrint("Image URL is not a network URL, trying as asset: $imageUrl");
    return Image.asset(
      imageUrl,
      height: 180,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        debugPrint("Error loading asset image '$imageUrl': $error");
        return _buildPlaceholderImage(error: true);
      },
    );
  }

  Widget _buildPlaceholderImage({bool error = false}) {
    return Container(
      height: 180,
      width: double.infinity,
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            error ? Icons.broken_image_outlined : Icons.directions_car_filled_outlined,
            size: 60,
            color: Colors.grey[500],
          ),
          if (error)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "Image indisponible",
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<Map<String, dynamic>> _createPaymentIntent(String amount, String currency) async {
    try {
      final body = {
        'amount': (double.parse(amount) * 100).round().toString(),
        'currency': currency.toLowerCase(),
        'payment_method_types[]': 'card',
      };

      final response = await http.post(
        Uri.parse("https://api.stripe.com/v1/payment_intents"),
        headers: {
          "Authorization": "Bearer $_stripeSecretKey",
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['error']?['message'] ?? "Unknown Error";
        debugPrint("Error creating payment intent: ${response.statusCode} - $errorMessage - Body: ${response.body}");
        throw Exception("Erreur de création de l'intention de paiement: ${response.statusCode} $errorMessage");
      }
    } catch (e) {
      debugPrint("Exception in _createPaymentIntent: $e");
      throw Exception("Impossible de communiquer avec le service de paiement: ${e.toString()}");
    }
  }

  Future<void> _initializeAndPresentPaymentSheet(String totalAmount) async {
    try {
      _paymentIntentData = await _createPaymentIntent(totalAmount, "USD");

      if (_paymentIntentData == null || _paymentIntentData!['client_secret'] == null) {
        debugPrint("Invalid payment intent data: $_paymentIntentData");
        throw Exception("Données d'intention de paiement invalides reçues.");
      }
      debugPrint("Payment Intent created.");

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: _paymentIntentData!['client_secret'],
          merchantDisplayName: "Khadija Auto Rentals",
          style: ThemeMode.system,
        ),
      );
      debugPrint("Payment Sheet initialized.");

      await Stripe.instance.presentPaymentSheet();
      debugPrint("Payment Sheet presented and completed (or cancelled/failed).");

      _showSnackBar("Paiement effectué avec succès (étape client)!");
      _paymentIntentData = null;

    } on StripeException catch (e) {
      _paymentIntentData = null;
      debugPrint("Stripe Exception during payment flow: ${e.error.code} - ${e.error.message}");
      if (e.error.code == FailureCode.Canceled) {
        throw Exception('Paiement annulé par l\'utilisateur.');
      } else {
        throw Exception('Échec du paiement: ${e.error.localizedMessage ?? e.toString()}');
      }
    } catch (e) {
      _paymentIntentData = null;
      debugPrint("Generic Error during payment flow: $e");
      throw Exception("Erreur lors du processus de paiement: ${e.toString()}");
    }
  }

  Widget _buildVehiclesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: AppConstants.screenPadding.copyWith(bottom: 8.0),
          child: Text(
            'Véhicules Disponibles',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value.trim()),
            decoration: InputDecoration(
              hintText: "Rechercher par modèle...",
              prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainer.withAlpha((255 * 0.5).round()),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<List<Vehicle>>(
            stream: _vehicleController.getAllVehicles(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                debugPrint('Stream error in vehicles tab: ${snapshot.error}');
                return Center(
                    child: Text(
                      "Erreur de chargement: ${snapshot.error}",
                      style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                    child: Text("Aucun véhicule dans le système.", style: TextStyle(fontSize: 18)));
              }

              // Filtre les véhicules disponibles et non bloqués
              final availableVehicles = snapshot.data!.where((v) => v.isAvailable && !v.isBlocked).toList();

              if (availableVehicles.isEmpty && _searchQuery.isEmpty) {
                return const Center(
                  child: Text(
                    "Tous les véhicules sont actuellement réservés ou bloqués.",
                    style: TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final filteredVehicles = availableVehicles
                  .where((v) => v.model.toLowerCase().contains(_searchQuery.toLowerCase()))
                  .toList();

              if (filteredVehicles.isEmpty && _searchQuery.isNotEmpty) {
                return Center(
                  child: Text(
                    "Aucun véhicule ne correspond à '$_searchQuery'.",
                    style: const TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              if (filteredVehicles.isEmpty) {
                return const Center(
                  child: Text(
                    "Aucun véhicule disponible pour le moment.",
                    style: TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.builder(
                padding: AppConstants.screenPadding.copyWith(top: 0),
                itemCount: filteredVehicles.length,
                itemBuilder: (context, index) {
                  final vehicle = filteredVehicles[index];
                  return material.Card( // Utilisation directe de Card
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: AppConstants.cardElevation,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildVehicleImage(vehicle.imageUrl), // Utilise la méthode améliorée
                        Padding(
                          padding: AppConstants.cardPadding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      vehicle.model,
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Chip(
                                    label: const Text('Disponible', style: TextStyle(color: Colors.white)),
                                    backgroundColor: Colors.green.shade600,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    avatar: const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Plaque: ${vehicle.licensePlate}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_pricePerDay.toStringAsFixed(2)} \$ / jour',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.calendar_today),
                                  label: const Text("Réserver Maintenant"),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppConstants.borderRadius - 4),
                                    ),
                                  ),
                                  onPressed: () async {
                                    if (_userId == null) {
                                      _showSnackBar('Veuillez vous connecter pour réserver.', isError: true);
                                      return;
                                    }

                                    final DateTimeRange? pickedRange = await showDateRangePicker(
                                        context: context,
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                        helpText: 'Sélectionnez la période de location',
                                        cancelText: 'Annuler',
                                        confirmText: 'Confirmer',
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              colorScheme: Theme.of(context).colorScheme.copyWith(
                                                primary: Theme.of(context).colorScheme.primary,
                                                onPrimary: Theme.of(context).colorScheme.onPrimary,
                                              ),
                                            ),
                                            child: child!,
                                          );
                                        }
                                    );

                                    if (pickedRange == null) {
                                      debugPrint("Date range picker cancelled.");
                                      return;
                                    }
                                    debugPrint("Date range selected: ${pickedRange.start} to ${pickedRange.end}");

                                    final int numberOfDays = pickedRange.duration.inDays + 1;
                                    if (numberOfDays <= 0) {
                                      _showSnackBar("La période de réservation doit être d'au moins un jour.", isError: true);
                                      return;
                                    }
                                    final double totalAmount = _pricePerDay * numberOfDays;
                                    debugPrint("Calculated total amount: $totalAmount for $numberOfDays days");

                                    try {
                                      await _initializeAndPresentPaymentSheet(totalAmount.toStringAsFixed(2));
                                      debugPrint("Payment sheet process completed.");

                                      await _reservationController.createReservation(
                                        userId: _userId!,
                                        vehicleId: vehicle.id, // vehicle.id est l'immatriculation maintenant
                                        startTime: pickedRange.start,
                                        endTime: pickedRange.end,
                                        amount: totalAmount,
                                        status: "Confirmé",
                                      );
                                      debugPrint("Reservation created in Firestore.");

                                      // Mettre à jour la disponibilité du véhicule dans Firestore
                                      await _vehicleController.updateVehicle(Vehicle(
                                        id: vehicle.id, // C'est l'immatriculation
                                        model: vehicle.model,
                                        licensePlate: vehicle.licensePlate,
                                        isAvailable: false, // Marquer comme indisponible
                                        imageUrl: vehicle.imageUrl,
                                        isBlocked: vehicle.isBlocked, // Conserver le statut bloqué
                                        homeLocation: vehicle.homeLocation, // Conserver la localisation
                                        timestamp: vehicle.timestamp, // Conserver le timestamp original
                                      ));
                                      debugPrint("Vehicle availability updated.");

                                      _showSnackBar('Réservation réussie pour ${vehicle.model}!');

                                    } catch (e) {
                                      debugPrint("Reservation process failed: $e");
                                      _showSnackBar('Erreur de réservation: ${e.toString().replaceFirst("Exception: ", "")}', isError: true);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReservationsTab() {
    if (_userId == null) {
      return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 60, color: Theme.of(context).colorScheme.secondary),
              const SizedBox(height: 16),
              const Text("Veuillez vous connecter pour voir vos réservations.", style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
              const SizedBox(height: 16),
            ],
          )
      );
    }

    return StreamBuilder<List<Reservation>>(
      stream: _reservationController.getReservationsByUser(_userId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          debugPrint('Stream error in reservations tab: ${snapshot.error}');
          return Center(
            child: Text(
              "Erreur: ${snapshot.error}",
              style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy_outlined, size: 60, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(height: 16),
                  const Text("Vous n'avez aucune réservation pour le moment.", style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
                ],
              )
          );
        }

        final reservations = snapshot.data!;
        return ListView.builder(
          padding: AppConstants.screenPadding,
          itemCount: reservations.length,
          itemBuilder: (context, index) {
            final reservation = reservations[index];

            return material.Card( // Utilisation directe de Card
              margin: const EdgeInsets.only(bottom: 16),
              elevation: AppConstants.cardElevation,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
              child: ListTile(
                contentPadding: AppConstants.cardPadding,
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(Icons.directions_car, color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
                title: Text(
                  // Afficher l'ID ou la plaque selon ce que vous préférez ici
                  'Réservation #${reservation.id.substring(0, 6)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    FutureBuilder<Vehicle?>(
                      // vehicleId est maintenant l'immatriculation
                      future: _vehicleController.getVehicleById(reservation.vehicleId),
                      builder: (context, vehicleSnapshot) {
                        if (vehicleSnapshot.connectionState == ConnectionState.waiting) {
                          return const Text('Chargement du véhicule...');
                        }
                        if (vehicleSnapshot.hasError || !vehicleSnapshot.hasData || vehicleSnapshot.data == null) {
                          debugPrint('Erreur ou véhicule non trouvé pour la réservation ${reservation.id}: ${vehicleSnapshot.error}');
                          return Text('Véhicule ID: ${reservation.vehicleId.substring(0, 6)}...');
                        }
                        return Text('Véhicule: ${vehicleSnapshot.data!.model}');
                      },
                    ),
                    Text('Du: ${reservation.startTime.toLocal().toString().substring(0, 16)}'),
                    Text('Au: ${reservation.endTime.toLocal().toString().substring(0, 16)}'),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('Statut: ', style: Theme.of(context).textTheme.bodySmall),
                        Chip(
                          label: Text(
                            reservation.status ?? "Confirmé",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: Theme.of(context).textTheme.bodySmall?.fontSize
                            ),
                          ),
                          backgroundColor: (reservation.status?.toLowerCase() == 'annulé')
                              ? Colors.grey
                              : Colors.orange.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total: ${reservation.amount.toStringAsFixed(2)} \$',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                trailing: (reservation.status?.toLowerCase() != 'annulé' && reservation.endTime.isAfter(DateTime.now()))
                    ? IconButton(
                  icon: Icon(Icons.cancel_outlined, color: Theme.of(context).colorScheme.error),
                  tooltip: 'Annuler la réservation',
                  onPressed: () async {
                    bool? confirmCancel = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext dialogContext) {
                        return AlertDialog(
                          title: const Text('Confirmer l\'annulation'),
                          content: const Text('Êtes-vous sûr de vouloir annuler cette réservation?\nCette action peut être soumise à des conditions.'),
                          actions: <Widget>[
                            TextButton(
                              child: const Text('Non'),
                              onPressed: () => Navigator.of(dialogContext).pop(false),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                              child: const Text('Oui, Annuler'),
                              onPressed: () => Navigator.of(dialogContext).pop(true),
                            ),
                          ],
                        );
                      },
                    );

                    if (confirmCancel == true) {
                      try {
                        await _reservationController.updateReservationStatus(reservation.id, "Annulé");

                        // Utilisation de vehicle.id (qui est l'immatriculation)
                        final vehicleToUpdate = await _vehicleController.getVehicleById(reservation.vehicleId);
                        if (vehicleToUpdate != null && !vehicleToUpdate.isAvailable) {
                          await _vehicleController.updateVehicle(
                            Vehicle(
                              id: vehicleToUpdate.id,
                              model: vehicleToUpdate.model,
                              licensePlate: vehicleToUpdate.licensePlate,
                              isAvailable: true, // Marquer comme disponible
                              imageUrl: vehicleToUpdate.imageUrl,
                              isBlocked: vehicleToUpdate.isBlocked,
                              homeLocation: vehicleToUpdate.homeLocation,
                              timestamp: vehicleToUpdate.timestamp,
                            ),
                          );
                          debugPrint("Vehicle ${vehicleToUpdate.id} marked as available after cancellation.");
                        } else if (vehicleToUpdate == null) {
                          debugPrint("Warning: Vehicle with ID ${reservation.vehicleId} not found during cancellation process.");
                        } else {
                          debugPrint("Vehicle ${vehicleToUpdate.id} was already available, no need to update.");
                        }
                        _showSnackBar('Réservation annulée avec succès.');
                      } catch (e) {
                        debugPrint("Cancellation process failed: $e");
                        _showSnackBar('Erreur lors de l\'annulation: ${e.toString().replaceFirst("Exception: ", "")}', isError: true);
                      }
                    }
                  },
                )
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProfileTab() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off_outlined, size: 60, color: Theme.of(context).colorScheme.secondary),
              const SizedBox(height: 16),
              const Text("Utilisateur non connecté.", style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
              const SizedBox(height: 16),
            ],
          )
      );
    }

    String initial = "U";
    if (_firstName?.isNotEmpty == true) {
      initial = _firstName![0].toUpperCase();
    } else if (_email?.isNotEmpty == true) {
      initial = _email![0].toUpperCase();
    }

    return SingleChildScrollView(
      padding: AppConstants.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          material.Card( // Utilisation directe de Card
            elevation: AppConstants.cardElevation,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      initial,
                      style: TextStyle(
                          fontSize: 40,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '${_firstName ?? 'Prénom non défini'} ${_lastName ?? 'Nom non défini'}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _email ?? 'Email non disponible',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _phoneNumber ?? 'Téléphone non défini',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Chip(
                    avatar: Icon(Icons.verified_user_outlined, color: Theme.of(context).colorScheme.onPrimary, size: 18),
                    label: Text('Client Vérifié', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            icon: const Icon(Icons.edit),
            label: const Text('Modifier le profil'),
            onPressed: () async {
              final bool? result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfilePage(
                    initialFirstName: _firstName,
                    initialLastName: _lastName,
                    initialPhoneNumber: _phoneNumber,
                    initialEmail: _email,
                  ),
                ),
              );

              if (result == true) {
                _loadUserData();
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 30),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius - 4),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Déconnexion'),
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
                debugPrint("User signed out successfully.");
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (Route<dynamic> route) => false);
                }
              } catch (e) {
                debugPrint("Error during sign out: $e");
                if (mounted) {
                  _showSnackBar('Erreur lors de la déconnexion: ${e.toString()}', isError: true);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 30),
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius - 4),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  List<Widget> get _tabs {
    return [
      _buildVehiclesTab(),
      _buildReservationsTab(),
      _buildProfileTab(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final List<String> tabTitles = ["Nos Véhicules", "Mes Réservations", "Mon Profil"];

    return Scaffold(
      appBar: AppBar(
        title: Text(tabTitles[_selectedIndex]),
        centerTitle: true,
        elevation: 1.0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: _selectedIndex == 2 // Le bouton de retour est pour l'onglet "Mon Profil" (index 2)
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _selectedIndex = 0; // Revient à l'onglet "Véhicules"
            });
          },
        )
            : null,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == 2) { // Si on navigue vers l'onglet profil (index 2)
            _loadUserData();
          }
          setState(() => _selectedIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey[600],
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 5.0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car_outlined),
            activeIcon: Icon(Icons.directions_car_filled),
            label: "Véhicules",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: "Réservations",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: "Profil",
          ),
        ],
      ),
    );
  }
}
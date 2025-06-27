import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:projectkhadija/Auth/auth.dart';
// import 'package:projectkhadija/Pages/Admin/AdminDashboard.dart'; // REMOVE THIS LINE IF UNUSED
import 'package:projectkhadija/Pages/Manager/manager.dart';
import 'package:projectkhadija/Pages/Client/Client.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:projectkhadija/Auth/Login.dart';
import 'package:projectkhadija/firebase_options.dart';
import 'package:projectkhadija/controller/VehicleController.dart';
import 'package:projectkhadija/controller/ReservationController.dart';
import 'package:projectkhadija/models/vehicle.dart';
import 'package:projectkhadija/models/reservation.dart';
import 'package:projectkhadija/Auth/welcome_page.dart';
import 'package:projectkhadija/controller/AlertsPage.dart'; // Importez AlertsPage
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_utils/google_maps_utils.dart';
import 'package:geodesy/geodesy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:projectkhadija/services/alert_listener.dart';
import 'package:permission_handler/permission_handler.dart'; // NOUVEL IMPORT

// Clé de navigation globale
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Plugin de notifications locales
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // NOUVEAU: Demander les permissions de notification (pour Android 13+)
  // Il est bon de le faire au démarrage ou avant la première notification.
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }

  // Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Supabase
  await Supabase.initialize(
    url: 'https://fmxucpdcnmpuomirvlrf.supabase.co',
    anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZteHVjcGRjbm1wdW9taXJ2bHJmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkwNjE4MTAsImV4cCI6MjA2NDYzNzgxMH0.0LdwJOtNNL-a61DF9qAMsy2DCGRYlkniKCYHqGZrg',
  );

  // Stripe
  const publicKey =
      "pk_test_51ROI81D6vrAub4vOM2IvRuvfhJLImR9QozuLiAzxOZQk3z5ZzfwkDDdcoHCtAVGtewRhD2CRJ4Vo3DJfvYXIcrzm00VeXOsjkB";
  Stripe.publishableKey = publicKey;
  Stripe.instance.applySettings();

  // Notifications locales - Initialisation
  const AndroidInitializationSettings androidSettings =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings =
  InitializationSettings(android: androidSettings);
  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse details) async {
      // Cette fonction est appelée quand l'utilisateur tape sur la notification
      if (details.payload != null) {
        // Redirection vers AlertsPage
        navigatorKey.currentState?.pushNamed('/alerts');
      }
    },
    // Si vous avez besoin de gérer les notifications quand l'app est en premier plan sur Android (optionnel)
    // onDidReceiveNotificationInForeground: (details) async {
    //   debugPrint('Notification received in foreground: ${details.id}');
    //   // Optionnel: Afficher une snackbar ou une alerte dans l'app si désiré
    // },
  );

  // NOUVEAU: Création du canal de notification pour Android 8.0+
  // L'ID du canal 'alerts_channel' DOIT correspondre à celui utilisé dans AlertListenerService
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'alerts_channel', // L'ID du canal (doit être unique)
    'Alertes Véhicules', // Le nom du canal visible par l'utilisateur
    description: 'Notifications importantes concernant les alertes véhicules', // Description visible par l'utilisateur
    importance: Importance.high, // Importance élevée pour les alertes critiques
    playSound: true,
    enableVibration: true,
  );

  // Crée le canal sur le système Android
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Lancement du service d'écoute des alertes
  AlertListenerService.startListening();

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Utilisation de la clé globale
      title: 'Réservation des voitures',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => WelcomePage(),
        '/alerts': (context) => const AlertsPage(), // Route vers AlertsPage
      },
    );
  }
}
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Écoute l’état d’authentification en temps réel
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// 🔐 Inscription avec email, mot de passe, prénom, nom, numéro de téléphone, rôle
  /// Les informations prénom, nom et numéro de téléphone sont stockées dans Firestore.
  /// Le nom d'affichage de Firebase Auth est mis à jour avec le prénom et le nom.
  Future<User?> signUp(
      String email,
      String password,
      String firstName,
      String lastName,
      String phoneNumber,
      String role,
      ) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;

      if (user != null) {
        // Mettre à jour le nom d'affichage dans Firebase Auth
        await user.updateDisplayName('$firstName $lastName');

        // Enregistrer les infos détaillées dans Firestore dans la collection 'users'
        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'role': role, // Par exemple, "client"
          'firstName': firstName,
          'lastName': lastName,
          'phoneNumber': phoneNumber,
          'createdAt': FieldValue.serverTimestamp(), // Date de création de l'utilisateur
        });
      }

      return user;
    } catch (e) {
      print('🚫 Erreur inscription: $e');
      rethrow; // Relancer l'exception pour que l'interface utilisateur puisse la gérer
    }
  }

  /// 🔓 Connexion avec email et mot de passe
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print('🚫 Erreur de connexion: $e');
      rethrow;
    }
  }

  /// 🔄 Met à jour les informations du profil utilisateur dans Firestore.
  /// L'email n'est pas modifiable via cette méthode pour des raisons de sécurité
  /// (nécessiterait une réauthentification pour Firebase Auth).
  Future<void> updateUserProfile(String uid, String firstName, String lastName, String phoneNumber) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'firstName': firstName,
        'lastName': lastName,
        'phoneNumber': phoneNumber,
      });

      // Optionnel: Mettre à jour le displayName de Firebase Auth si nécessaire
      // final user = _auth.currentUser;
      // if (user != null) {
      //   await user.updateDisplayName('$firstName $lastName');
      // }

    } catch (e) {
      print('🚫 Erreur mise à jour profil Firestore: $e');
      rethrow;
    }
  }

  /// 🔍 Récupère le rôle de l'utilisateur depuis Firestore
  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists ? doc.get('role') as String? : null;
    } catch (e) {
      print('🚫 Erreur récupération rôle: $e');
      return null;
    }
  }

  /// ❌ Déconnexion de l'utilisateur actuel
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// 🔁 Envoie un email de réinitialisation de mot de passe
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// 👤 Récupère le nom complet (prénom et nom) de l'utilisateur depuis Firestore.
  /// Combinaison des champs 'firstName' et 'lastName'.
  Future<String?> getUserName(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final firstName = doc.get('firstName') as String?;
        final lastName = doc.get('lastName') as String?;
        if (firstName != null && lastName != null) {
          return '$firstName $lastName';
        } else if (firstName != null) {
          return firstName;
        } else if (lastName != null) {
          return lastName;
        }
      }
      return null;
    } catch (e) {
      print('🚫 Erreur récupération nom complet: $e');
      return null;
    }
  }

  /// 👤 Récupère le prénom de l'utilisateur depuis Firestore
  Future<String?> getUserFirstName(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists ? doc.get('firstName') as String? : null;
    } catch (e) {
      print('🚫 Erreur récupération prénom: $e');
      return null;
    }
  }

  /// 👤 Récupère le nom de famille de l'utilisateur depuis Firestore
  Future<String?> getUserLastName(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists ? doc.get('lastName') as String? : null;
    } catch (e) {
      print('🚫 Erreur récupération nom de famille: $e');
      return null;
    }
  }

  /// 📞 Récupère le numéro de téléphone de l'utilisateur depuis Firestore
  Future<String?> getUserPhoneNumber(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists ? doc.get('phoneNumber') as String? : null;
    } catch (e) {
      print('🚫 Erreur récupération numéro de téléphone: $e');
      return null;
    }
  }
}
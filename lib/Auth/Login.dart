import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Auth/auth.dart';
import 'package:projectkhadija/Auth/Register.dart';
import 'package:projectkhadija/Pages/Admin/AdminDashboard.dart';
import 'package:projectkhadija/Pages/Manager/manager.dart';
import 'package:projectkhadija/Pages/Client/Client.dart';


// Constants
class _AppColors {
  static const Color primary = Colors.deepPurple;
  static const Color primaryLight = Color(0xFFEDE7F6);
  static const Color error = Colors.redAccent;
  static const Color textOnDarkBg = Colors.white; // Pour le texte sur l'image de fond
  static const Color hintTextOnDarkBg = Colors.white70;
  static const Color inputFillColor = Colors.white24; // Fond semi-transparent pour les champs
}

class _AppTextStyles {
  static TextStyle headline = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    color: _AppColors.textOnDarkBg, // Changé pour la lisibilité sur fond
    shadows: <Shadow>[ // Ajout d'ombre pour améliorer la lisibilité
      Shadow(
        offset: Offset(1.0, 1.0),
        blurRadius: 3.0,
        color: Color.fromARGB(150, 0, 0, 0),
      ),
    ],
  );
  static const TextStyle buttonText = TextStyle(fontSize: 16);
  static TextStyle linkText = TextStyle(color: _AppColors.primaryLight, fontWeight: FontWeight.w500); // Un lien plus clair
  static TextStyle errorText = const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold); // Erreur plus visible
}

class _AppStrings {
  static const String welcome = 'Bienvenue !';
  static const String emailLabel = 'Email';
  static const String passwordLabel = 'Mot de passe';
  static const String emailHint = 'entrez votre email';
  static const String passwordHint = 'entrez votre mot de passe';
  static const String requiredField = 'Ce champ est requis';
  static const String invalidEmail = 'Veuillez entrer un email valide';
  static const String forgotPassword = 'Mot de passe oublié ?';
  static const String loginButton = 'Se connecter';
  static const String registerPrompt = 'Pas de compte ?';
  static const String registerLink = 'S\'inscrire';
  static const String loading = 'Chargement...';
  static const String resetPasswordEmailPrompt = 'SVP entrer votre email pour réinitialiser le mot de passe';
  static const String resetPasswordSuccess = 'Email de réinitialisation envoyé à';
  static const String resetPasswordError = 'Erreur lors de l\'envoi de l\'email de réinitialisation';
  static const String loginError = 'Erreur de connexion. Vérifiez vos identifiants.';
  static const String genericError = 'Une erreur est survenue';
  static const String backgroundImagePath = 'images/S4.jpg'; // Chemin de l'image
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _setLoading(bool loading) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
        if (loading) _errorMessage = null;
      });
    }
  }

  void _setError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
      });
    }
  }

  Future<void> _performLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _setLoading(true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final user = await authService.signIn(email, password);
      if (!mounted) return;
      if (user != null) {
        final role = await authService.getUserRole(user.uid);
        if (!mounted) return;
        _navigateToDashboard(role);
      } else {
        _setError(_AppStrings.loginError);
      }
    } catch (e) {
      _setError(e.toString().contains('user-not-found') || e.toString().contains('wrong-password')
          ? _AppStrings.loginError
          : _AppStrings.genericError);
    } finally {
      _setLoading(false);
    }
  }

  void _navigateToDashboard(String? role) {
    Widget? destinationPage;
    switch (role) {
      case 'admin':
        destinationPage = AdminDashboard(); // Mettre const si possible
        break;
      case 'gestionnaire':
        destinationPage = ManagerDashboard(); // Mettre const si possible
        break;
      case 'client':
        destinationPage = const ClientDashboard(); // Mettre const si possible
        break;
      default:
        _setError('Rôle utilisateur non reconnu.');
        return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => destinationPage!),
    );
  }

  Future<void> _handlePasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar(_AppStrings.resetPasswordEmailPrompt, isError: true);
      return;
    }

    _setLoading(true);
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      await authService.resetPassword(email);
      if (!mounted) return;
      _showSnackBar('${_AppStrings.resetPasswordSuccess} $email');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('${_AppStrings.resetPasswordError}: ${e.toString()}', isError: true);
    } finally {
      _setLoading(false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _AppColors.error : Theme.of(context).snackBarTheme.backgroundColor,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint, IconData icon) {
    // Adaptons les couleurs pour la lisibilité sur l'image de fond
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _AppColors.hintTextOnDarkBg),
      hintText: hint,
      hintStyle: TextStyle(color: _AppColors.hintTextOnDarkBg.withOpacity(0.7)),
      prefixIcon: Icon(icon, color: _AppColors.primaryLight),
      filled: true, // Important pour que fillColor soit visible
      fillColor: _AppColors.inputFillColor, // Fond semi-transparent pour les champs
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _AppColors.primaryLight.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _AppColors.primaryLight, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _AppColors.primaryLight.withOpacity(0.3)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _AppColors.error, width: 2),
      ),
      errorStyle: TextStyle(color: Colors.yellowAccent[100], fontWeight: FontWeight.bold),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.grey[50], // On va utiliser une image de fond
      body: Container( // ****** NOUVEAU : Container pour l'image de fond ******
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(_AppStrings.backgroundImagePath), // Utiliser la constante
            fit: BoxFit.cover, // Pour que l'image couvre tout l'écran
            // Optionnel: ajouter un filtre de couleur pour assombrir/éclaircir l'image
            // afin d'améliorer la lisibilité du texte par dessus.
            // colorFilter: ColorFilter.mode(
            //   Colors.black.withOpacity(0.4), // Exemple: assombrir l'image
            //   BlendMode.darken,
            // ),
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container( // Optionnel: un container pour le formulaire avec un fond légèrement transparent
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35), // Fond semi-transparent pour le bloc de formulaire
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Icon(Icons.lock_person_rounded, size: 80, color: _AppColors.primaryLight),
                      const SizedBox(height: 20),
                      Text(
                        _AppStrings.welcome,
                        style: _AppTextStyles.headline, // Style ajusté pour lisibilité
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: _AppColors.error.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: _AppTextStyles.errorText.copyWith(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],

                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: _AppColors.textOnDarkBg), // Couleur du texte saisi
                        decoration: _inputDecoration(_AppStrings.emailLabel, _AppStrings.emailHint, Icons.email_outlined),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return _AppStrings.requiredField;
                          }
                          if (!RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
                            return _AppStrings.invalidEmail;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        style: TextStyle(color: _AppColors.textOnDarkBg), // Couleur du texte saisi
                        decoration: _inputDecoration(_AppStrings.passwordLabel, _AppStrings.passwordHint, Icons.lock_outline),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return _AppStrings.requiredField;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : _handlePasswordReset,
                          child: Text(
                            _AppStrings.forgotPassword,
                            style: _AppTextStyles.linkText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: _AppTextStyles.buttonText,
                        ),
                        onPressed: _isLoading ? null : _performLogin,
                        child: _isLoading
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                            : const Text(_AppStrings.loginButton),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_AppStrings.registerPrompt, style: TextStyle(color: _AppColors.hintTextOnDarkBg)),
                          TextButton(
                            onPressed: _isLoading ? null : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => RegisterPage()),
                              );
                            },
                            child: Text(
                              _AppStrings.registerLink,
                              style: _AppTextStyles.linkText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
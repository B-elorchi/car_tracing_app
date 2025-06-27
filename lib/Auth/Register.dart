import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for SystemUiOverlayStyle
import 'package:provider/provider.dart';
import 'package:projectkhadija/Auth/auth.dart';
import 'package:projectkhadija/Pages/Client/Client.dart';
// If you have different dashboards for manager/admin and navigate based on role,
// ensure these imports are still relevant based on your final navigation logic.
// import 'package:projectkhadija/Pages/Admin/AdminDashboard.dart';
// import 'package:projectkhadija/Pages/Manager/manager.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final String _fixedRole = 'client'; // Rôle fixé à 'client' pour l'inscription

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _setLoading(bool loading) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
        if (loading) _errorMessage = null; // Clear error on new attempt
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

  // --- NOUVELLE MÉTHODE : Afficher une SnackBar ---
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Theme.of(context).primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- NOUVELLE MÉTHODE : Gérer la réinitialisation du mot de passe ---
  Future<void> _handlePasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar('SVP, entrez votre email pour réinitialiser le mot de passe.', isError: true);
      return;
    }

    _setLoading(true);
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      await authService.resetPassword(email);
      if (!mounted) return;
      _showSnackBar('Email de réinitialisation envoyé à $email');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Erreur lors de l\'envoi de l\'email de réinitialisation: ${e.toString().replaceFirst("Exception: ", "")}', isError: true);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _performRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    _setLoading(true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phoneNumber = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final user = await authService.signUp(
        email,
        password,
        firstName,
        lastName,
        phoneNumber,
        _fixedRole, // Rôle fixé à 'client'
      );

      if (!mounted) return;

      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ClientDashboard()),
        );
      } else {
        _setError('Erreur lors de l\'inscription.');
      }
    } catch (e) {
      _setError(e.toString().contains('email-already-in-use')
          ? 'Cet email est déjà utilisé.'
          : 'Une erreur est survenue: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      _setLoading(false);
    }
  }

  // Helper widget for consistent TextFormField styling
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(color: Colors.white), // Input text color
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.7)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1), // Background color of the input field
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none, // No visible border
        ),
        enabledBorder: OutlineInputBorder( // Same for enabled state
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder( // Slight border on focus
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.0),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar icons to light (white) to contrast with dark background
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.transparent, // Make Scaffold background transparent to show Stack
        body: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Image.asset(
                'images/S4.jpg', // Ensure this path matches your asset location
                fit: BoxFit.cover,
              ),
            ),
            // Overlay content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 60.0),
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Title
                        const Text(
                          "Créer un compte",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),

                        // Error Message
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        // First Name Input (Prénom)
                        _buildTextFormField(
                          controller: _firstNameController,
                          hintText: 'Prénom',
                          icon: Icons.person_outline,
                          validator: (value) => value == null || value.isEmpty ? 'Champ requis' : null,
                        ),
                        const SizedBox(height: 16),

                        // Last Name Input (Nom)
                        _buildTextFormField(
                          controller: _lastNameController,
                          hintText: 'Nom',
                          icon: Icons.person,
                          validator: (value) => value == null || value.isEmpty ? 'Champ requis' : null,
                        ),
                        const SizedBox(height: 16),

                        // Phone Number Input (Téléphone)
                        _buildTextFormField(
                          controller: _phoneController,
                          hintText: 'Téléphone',
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Champ requis';
                            if (!RegExp(r'^[0-9]+$').hasMatch(value)) return 'Numéro de téléphone invalide';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Email Input
                        _buildTextFormField(
                          controller: _emailController,
                          hintText: 'Email',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Champ requis';
                            if (!value.contains('@')) return 'Email invalide';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password Input (Mot de passe)
                        _buildTextFormField(
                          controller: _passwordController,
                          hintText: 'Mot de passe',
                          icon: Icons.lock,
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Champ requis';
                            if (value.length < 6) return 'Minimum 6 caractères';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Forgot Password Text (Maintenant fonctionnel)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isLoading ? null : _handlePasswordReset, // Appelle la nouvelle méthode
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Mot de passe oublié ?',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Register Button (S'inscrire)
                        ElevatedButton(
                          onPressed: _isLoading ? null : _performRegistration,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF673AB7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            minimumSize: const Size.fromHeight(50),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                            'S\'inscrire',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Already have an account? Login text
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Déjà un compte ? ',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 15,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context); // Navigue vers la page de connexion
                              },
                              child: const Text(
                                'Se connecter',
                                style: TextStyle(
                                  color: Color(0xFF673AB7),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
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
          ],
        ),
      ),
    );
  }
}
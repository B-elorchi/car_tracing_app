// lib/services/stripe_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
 // For debugPrint

class StripeService {
  // Dummy publishable key for testing (will fail but allows UI attempt)
  static const String publishableKey = 'pk_test_dummy_key';

  // Initialize Stripe with dummy key
  static void init() {
    try {
      Stripe.publishableKey = publishableKey;
      debugPrint('Stripe initialized with dummy key');
    } catch (e) {
      debugPrint('Stripe Init Error: $e');
    }
  }

  static Future<void> openStripeCheckout({
    required BuildContext context,
    required double amount,
    required String reservationId,
    required VoidCallback onSuccess,
    required VoidCallback onError,
    required VoidCallback onCancel,
  }) async {
    debugPrint('Attempting Stripe checkout for reservation: $reservationId');
    try {
      // Create a Payment Intent (mocked for testing without backend)
      final paymentIntent = await _createPaymentIntent(amount, reservationId);

      // Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: "pk_test_51ROI81D6vrAub4vOM2IvRuvfhJLImR9QozuLiAzxOZQk3z5ZzfwkDDdcoHCtAVGtewRhD2CRJ4Vo3DJfvYXIcrzm00VeXOsjkB",
          merchantDisplayName: 'Car Rental',
          allowsDelayedPaymentMethods: true,
        ),
      );

      // Present payment sheet
      await Stripe.instance.presentPaymentSheet().then((_) {
        debugPrint('Stripe Payment Successful');
        onSuccess();
      }).catchError((e) {
        debugPrint('Stripe Payment Error: $e');
        onError();
      });
    } catch (e) {
      debugPrint('Stripe Checkout Error: $e');
      onError();
    }
  }

  // Mock Payment Intent creation (normally requires backend)
  static Future<Map<String, dynamic>> _createPaymentIntent(double amount, String reservationId) async {
    try {
      // Simulate Payment Intent response for testing
      debugPrint('Simulating Payment Intent for amount: ${amount * 100} cents');
      return {
        'client_secret': 'dummy_client_secret', // Dummy for testing
        'id': 'pi_dummy_$reservationId',
      };
    } catch (e) {
      debugPrint('Payment Intent Error: $e');
      throw Exception('Failed to create Payment Intent');
    }
  }
}
// lib/controller/CommandsPage.dart
import 'package:flutter/material.dart';

class CommandsPage extends StatelessWidget {
  const CommandsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings_remote, size: 80, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            'Page des Commandes',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            'Ici, vous pourrez envoyer des commandes aux véhicules (ex: verrouiller, déverrouiller, démarrer/arrêter le moteur).',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
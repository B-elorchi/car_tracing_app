import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:projectkhadija/models/vehicle.dart';
import '../../../controller/VehicleController.dart';

class VehicleHistoryTab extends StatelessWidget {
  final VehicleController vehicleController;

  const VehicleHistoryTab({Key? key, required this.vehicleController}) : super(key: key);

  Future<List<Map<String, dynamic>>> fetchVehicleHistory(String plate) async {
    final url = Uri.parse('http://10.0.2.2:3000/api/location/$plate');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      final historyList = jsonData['data']['history'] as List;

      return historyList.map<Map<String, dynamic>>((item) {
        final time = DateTime.parse(item['timestamp']);
        final location = item['location'];
        return {
          'time': time,
          'location': '${location['latitude']}, ${location['longitude']}',
          'status': 'Marche', // Par défaut "Marche", mais tu peux l’adapter
        };
      }).toList().reversed.toList(); // Du plus récent au plus ancien
    } else {
      throw Exception('Erreur serveur: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Vehicle>>(
      stream: vehicleController.getAllVehicles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("Aucun véhicule trouvé."));
        }

        final vehicles = snapshot.data!;
        return ListView.builder(
          itemCount: vehicles.length,
          itemBuilder: (context, index) {
            final vehicle = vehicles[index];
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: fetchVehicleHistory(vehicle.id),
              builder: (context, historySnapshot) {
                if (historySnapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                } else if (historySnapshot.hasError) {
                  return ListTile(
                    title: Text(vehicle.model),
                    subtitle: Text('Erreur chargement historique : ${historySnapshot.error}'),
                  );
                }

                final history = historySnapshot.data!;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: ExpansionTile(
                    leading: Icon(Icons.directions_car_filled_outlined,
                        color: Theme.of(context).primaryColor, size: 30),
                    title: Text(vehicle.model,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'Dernière mise à jour: ${vehicle.timestamp?.toDate().toLocal().toString().split('.')[0] ?? 'Inconnue'}',
                    ),
                    children: history.map((entry) {
                      return ListTile(
                        leading: Icon(
                          entry['status'] == 'Marche'
                              ? Icons.directions_car
                              : Icons.stop,
                          color: entry['status'] == 'Marche'
                              ? Colors.green
                              : Colors.red,
                        ),
                        title: Text('${entry['status']} - ${entry['location']}'),
                        subtitle: Text(
                          'Heure: ${entry['time'].toLocal().toString().split('.')[0]}',
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

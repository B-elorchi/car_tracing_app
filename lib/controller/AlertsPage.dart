import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  bool _isAdmin = false;
  bool _isLoading = true;
  bool _isDeletingAll = false; // Pour gérer l'état de la suppression de toutes les alertes

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (mounted) {
          setState(() {
            _isAdmin = doc.exists && doc.data()?['role'] == 'admin';
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isAdmin = false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Erreur admin: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Ajustement pour gérer à la fois 'timestamp' (de l'API, converti en Timestamp) et 'createdAt' (de Firebase)
  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(timestamp.toDate());
    } else if (timestamp is String) { // Au cas où le champ serait encore une chaîne pour une raison X (pas attendu après le changement)
      try {
        return DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.parse(timestamp));
      } catch (_) {
        return 'Date invalide';
      }
    }
    return 'Date inconnue';
  }

  Future<void> _deleteAlert(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Voulez-vous vraiment supprimer cette alerte ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('alerts').doc(id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alerte supprimée avec succès')),
          );
        }
      } catch (e) {
        debugPrint('Erreur suppression: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors de la suppression')),
          );
        }
      }
    }
  }

  Future<void> _deleteAllAlerts() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmation de suppression globale'),
        content: const Text(
            'Voulez-vous vraiment supprimer TOUTES les alertes ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Tout Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (mounted) setState(() => _isDeletingAll = true);
      try {
        final alertsCollection = FirebaseFirestore.instance.collection('alerts');
        final QuerySnapshot snapshot = await alertsCollection.get();

        if (snapshot.docs.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Aucune alerte à supprimer.')),
            );
          }
          return;
        }

        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (DocumentSnapshot doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Toutes les alertes ont été supprimées avec succès')),
          );
        }
      } catch (e) {
        debugPrint('Erreur suppression globale: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Erreur lors de la suppression de toutes les alertes')),
          );
        }
      } finally {
        if (mounted) setState(() => _isDeletingAll = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Historique des Alertes')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Historique des Alertes')),
        body: const Center(child: Text('Accès réservé aux administrateurs')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des Alertes'),
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        actions: [
          if (_isAdmin) // S'assurer que seul l'admin voit ce bouton
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Supprimer toutes les alertes',
              onPressed: _isDeletingAll ? null : _deleteAllAlerts, // Désactiver pendant la suppression
            ),
        ],
      ),
      body: Stack( // Utiliser un Stack pour superposer un indicateur de chargement si nécessaire
        children: [
          StreamBuilder<QuerySnapshot>(
            // Utiliser 'createdAt' pour le tri, car c'est le timestamp Firebase standard
            stream: FirebaseFirestore.instance
                .collection('alerts')
                .orderBy('createdAt', descending: true) // Trie par le timestamp de création Firebase
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}'));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('Aucune alerte enregistrée.'));
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 4,
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber_rounded,
                          color: Colors.red, size: 32),
                      title: Text(
                        data['message'] ?? 'Alerte inconnue',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDate(data['createdAt'] ?? data['timestamp']), // Utilisez createdAt en priorité
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            if (data['plate'] != null)
                              Text('Plaque : ${data['plate']}'),
                            if (data['location'] != null &&
                                data['location']['latitude'] != null &&
                                data['location']['longitude'] != null)
                              Text(
                                'Coordonnées : ${data['location']['latitude'].toStringAsFixed(4)}, ${data['location']['longitude'].toStringAsFixed(4)}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                          ],
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.grey),
                        onPressed: () => _deleteAlert(doc.id),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          if (_isDeletingAll) // Afficher un indicateur de chargement au centre pendant la suppression globale
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text("Suppression en cours...", style: TextStyle(color: Colors.white)),
                    ],
                  )
              ),
            ),
        ],
      ),
    );
  }
}
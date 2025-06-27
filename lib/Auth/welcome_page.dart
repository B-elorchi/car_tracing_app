import 'package:flutter/material.dart';
import 'package:projectkhadija/Auth/Login.dart';


class WelcomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('images/khadija.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Transparent overlay (optionnel)
          Container(
            color: Colors.black.withOpacity(0.3),
          ),
          // Button
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[400],
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  "COMMENCER ",
                  style: TextStyle(fontSize: 36, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

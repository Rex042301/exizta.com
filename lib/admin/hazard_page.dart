import 'package:flutter/material.dart';

class HazardPage extends StatelessWidget {
  const HazardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hazard"),
        backgroundColor: Colors.brown,
      ),
      body: const Center(
        child: Text(
          "Hazard Page Content",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}

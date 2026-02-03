import 'package:flutter/material.dart';

class FacilitiesPage extends StatelessWidget {
  const FacilitiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Facilities"),
        backgroundColor: Colors.purple,
      ),
      body: const Center(
        child: Text(
          "Facilities Page Content",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}

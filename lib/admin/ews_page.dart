import 'package:flutter/material.dart';

class EWSPage extends StatelessWidget {
  const EWSPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Early Warning System"),
        backgroundColor: Colors.orange,
      ),
      body: const Center(
        child: Text(
          "EWS Page Content",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}

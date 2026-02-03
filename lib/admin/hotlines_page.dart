import 'package:flutter/material.dart';

class HotlinesPage extends StatelessWidget {
  const HotlinesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hotlines"),
        backgroundColor: Colors.teal,
      ),
      body: const Center(
        child: Text(
          "Hotlines Page Content",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}

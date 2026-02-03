import 'package:flutter/material.dart';

class MobileView extends StatelessWidget {
  // PALITAN ITO: Mula List<QueryDocumentSnapshot> tungo sa List<Map<String, dynamic>>
  final List<Map<String, dynamic>> docs;

  const MobileView({super.key, required this.docs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mobile Alerts")),
      body: ListView.builder(
        itemCount: docs.length,
        itemBuilder: (context, index) {
          final item = docs[index];
          return Card(
            child: ListTile(
              title: Text(item['type'] ?? 'No Title'),
              subtitle: Text(item['description'] ?? 'No Description'),
            ),
          );
        },
      ),
    );
  }
}
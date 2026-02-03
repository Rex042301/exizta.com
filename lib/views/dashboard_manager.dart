import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'mobile_view.dart';
import 'desktop_view.dart';

class DashboardManager extends StatelessWidget {
  const DashboardManager({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sos_alerts')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        // No data
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Scaffold(
            body: Center(
              child: Text(
                'No active SOS alerts',
                style: TextStyle(fontSize: 18),
              ),
            ),
          );
        }

        // Convert Firestore docs to List<Map>
        final incidents = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'type': data['type'] ?? 'SOS Alert',
            'description': data['description'] ?? 'Emergency reported',
            'severity': data['severity'] ?? 'Critical',
            'status': data['status'] ?? 'Active',
            'userId': data['userId'],
            'timestamp': data['timestamp'],
          };
        }).toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 800) {
              return MobileView(docs: incidents);
            } else {
              return DesktopView(docs: incidents);
            }
          },
        );
      },
    );
  }
}

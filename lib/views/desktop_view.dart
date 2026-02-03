import 'package:flutter/material.dart';

class DesktopView extends StatelessWidget {
  final List<Map<String, dynamic>> docs;
  const DesktopView({super.key, required this.docs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // TANGGALIN ANG CONST DITO
          NavigationRail(
            extended: true,
            backgroundColor: const Color(0xFF1A1A1A),
            unselectedIconTheme: const IconThemeData(color: Colors.white60),
            selectedIconTheme: const IconThemeData(color: Colors.white),
            destinations: const [
              NavigationRailDestination(
                  icon: Icon(Icons.security),
                  label: Text("Alerts", style: TextStyle(color: Colors.white))
              ),
              NavigationRailDestination(
                  icon: Icon(Icons.analytics),
                  label: Text("AI Analysis", style: TextStyle(color: Colors.white))
              ),
            ],
            selectedIndex: 0,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.5,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final item = docs[index];
                  bool isCritical = item['severity'] == 'Critical';
                  return Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: isCritical ? Colors.red.withOpacity(0.1) : Colors.white10,
                      border: Border.all(color: isCritical ? Colors.red : Colors.grey),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['type'] ?? 'Emergency', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 10),
                        Text(item['description'] ?? '', style: const TextStyle(color: Colors.white70)),
                        const Spacer(),
                        const Text("STATUS: ACTIVE", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
            ),
          )
        ],
      ),
    );
  }
}
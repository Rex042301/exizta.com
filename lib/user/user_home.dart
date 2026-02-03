import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'notification.dart'; // Import natin ang model

class UserHome extends StatefulWidget {
  const UserHome({super.key});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  final String apiKey = "fe5a11561b18c04c0ffdcf0ab173bea7";
  final String city = "Manila";

  // Local list para pwedeng i-delete
  List<EmergencyAlert> alerts = List.from(mockAlerts);

  Future<Map<String, dynamic>> fetchWeather() async {
    final url = 'https://api.openweathermap.org/data/2.5/weather?q=$city&units=metric&appid=$apiKey';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception("Failed to load");
  }

  void _deleteAlert(int index) {
    setState(() {
      alerts.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Alert deleted"), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Current Status", style: _headingStyle),
              const SizedBox(height: 15),
              _buildSafetyStatus(isEmergency: false),

              const SizedBox(height: 35),
              const Text("Emergency History", style: _headingStyle),
              const SizedBox(height: 15),
              _buildHistoryList(), // Dito ang list na may delete

              const SizedBox(height: 35),
              const Text("Real-Time Weather", style: _headingStyle),
              const SizedBox(height: 15),
              _buildWeatherSection(),

              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (alerts.isEmpty) {
      return const Center(child: Text("No alerts found", style: TextStyle(color: Colors.white24)));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        final item = alerts[index];
        return Dismissible(
          key: Key(item.id),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) => _deleteAlert(index),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(25)),
            child: const Icon(Icons.delete_outline, color: Colors.redAccent),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => _showPopCard(item),
              child: _glassContainer(
                padding: 15,
                child: Row(
                  children: [
                    _getLeadingIcon(item.type),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text(item.time, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white24, size: 18),
                      onPressed: () => _deleteAlert(index),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- UI COMPONENTS ---

  void _showPopCard(EmergencyAlert alert) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _glassContainer(
        padding: 30,
        customColor: Colors.black.withOpacity(0.95),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Text(alert.body, style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Dismiss", style: TextStyle(color: Colors.blueAccent)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _getLeadingIcon(String type) {
    Color color = type == 'emergency' ? Colors.redAccent : Colors.orangeAccent;
    return Icon(Icons.circle, color: color, size: 12);
  }

  Widget _buildWeatherSection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: fetchWeather(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final data = snapshot.data!;
        return _glassContainer(
          child: Text("${data['main']['temp']}°C in $city", style: const TextStyle(color: Colors.white)),
        );
      },
    );
  }

  Widget _buildSafetyStatus({required bool isEmergency}) {
    return _glassContainer(
      customColor: isEmergency ? Colors.redAccent.withOpacity(0.1) : Colors.greenAccent.withOpacity(0.05),
      child: const Text("System Secure", style: TextStyle(color: Colors.greenAccent)),
    );
  }

  Widget _glassContainer({required Widget child, Color? customColor, double padding = 20}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: customColor ?? Colors.white.withOpacity(0.05),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(25),
          ),
          child: child,
        ),
      ),
    );
  }

  static const _headingStyle = TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18);
}
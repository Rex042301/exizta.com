import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class UserHome extends StatefulWidget {
  const UserHome({super.key});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  final String apiKey = "fe5a11561b18c04c0ffdcf0ab173bea7";
  final String city = "Manila";

  Future<Map<String, dynamic>> fetchWeather() async {
    final url =
        'https://api.openweathermap.org/data/2.5/weather?q=$city&units=metric&appid=$apiKey';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to load weather");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Current Status", style: _headingStyle),
              const SizedBox(height: 15),
              _buildSafetyStatus(),

              const SizedBox(height: 40),
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

  // ---------------- UI COMPONENTS ----------------

  Widget _buildWeatherSection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: fetchWeather(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }

        if (snapshot.hasError) {
          return _glassContainer(
            child: const Text(
              "Weather unavailable",
              style: TextStyle(color: Colors.white38),
            ),
          );
        }

        final data = snapshot.data!;
        final temp = data['main']['temp'];
        final desc = data['weather'][0]['description'];

        return _glassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$temp°C",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Text(
                "$desc in $city",
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSafetyStatus() {
    return _glassContainer(
      customColor: Colors.greenAccent.withOpacity(0.08),
      child: Row(
        children: const [
          Icon(Icons.verified_rounded, color: Colors.greenAccent),
          SizedBox(width: 10),
          Text(
            "System Secure",
            style: TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _glassContainer({
    required Widget child,
    Color? customColor,
    double padding = 20,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: customColor ?? Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  static const _headingStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
    fontSize: 18,
  );
}

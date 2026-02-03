import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class SosAiPage extends StatefulWidget {
  const SosAiPage({super.key});

  @override
  State<SosAiPage> createState() => _SosAiPageState();
}

class _SosAiPageState extends State<SosAiPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _chatMessages = [];

  bool _sosActive = false;
  bool _loading = false;

  String _incidentType = 'medical';
  String _incidentRelation = 'self';

  /// ---------------- INCIDENT SELECTION ----------------
  Future<void> _selectIncidentDetails() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Incident Details",
              style: TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            value: _incidentType,
            dropdownColor: Colors.grey[900],
            decoration: const InputDecoration(
              labelText: "Incident Type",
              labelStyle: TextStyle(color: Colors.white70),
            ),
            items: const [
              DropdownMenuItem(value: 'medical', child: Text("Medical")),
              DropdownMenuItem(value: 'assault', child: Text("Assault / Threat")),
              DropdownMenuItem(value: 'accident', child: Text("Accident")),
              DropdownMenuItem(value: 'fire', child: Text("Fire")),
              DropdownMenuItem(value: 'other', child: Text("Other")),
            ],
            onChanged: (v) => setState(() => _incidentType = v!),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _incidentRelation,
            dropdownColor: Colors.grey[900],
            decoration: const InputDecoration(
              labelText: "Who is affected?",
              labelStyle: TextStyle(color: Colors.white70),
            ),
            items: const [
              DropdownMenuItem(value: 'self', child: Text("Me")),
              DropdownMenuItem(value: 'someone_else', child: Text("Someone Else")),
              DropdownMenuItem(value: 'witness', child: Text("I am a Witness")),
            ],
            onChanged: (v) => setState(() => _incidentRelation = v!),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context),
            child: const Text("Confirm"),
          )
        ]),
      ),
    );
  }

  /// ---------------- SOS TRIGGER ----------------
  Future<void> _triggerSos() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _loading = true;
      _sosActive = true;
    });

    try {
      // Get current location
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      // Get human-readable address
      String address = "Fetching address...";
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        try {
          final placemarks =
          await geo.placemarkFromCoordinates(pos.latitude, pos.longitude);
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            address = "${p.street}, ${p.locality}";
          }
        } catch (_) {}
      } else {
        final res = await http.get(
          Uri.parse(
              "https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}"),
          headers: {'User-Agent': 'SOSApp/1.0'},
        );
        if (res.statusCode == 200) {
          address = json.decode(res.body)['display_name'] ?? address;
        }
      }

      // Get user info
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userName =
          userDoc.data()?['name'] ?? user.displayName ?? "User";

      // Add SOS trigger to Firestore
      final docRef =
      await FirebaseFirestore.instance.collection('sos_triggers').add({
        'userId': user.uid,
        'email': user.email,
        'userName': userName,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'address': address,
        'incidentType': _incidentType,
        'incidentRelation': _incidentRelation,
        'hourOfTrigger': DateFormat('hh:mm a').format(DateTime.now()),
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'active',
        'platform': kIsWeb ? "Web" : Platform.operatingSystem,
      });

      // Update AI chat with response
      setState(() {
        _chatMessages.add({
          'sender': 'ai',
          'message':
          "Hello $userName. Help is on the way.\nIncident: $_incidentType\nLocation: $address"
        });
      });

      _showSosDialog(docRef.id);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("SOS failed")));
    } finally {
      setState(() => _loading = false);
    }
  }

  /// ---------------- SOS DIALOG ----------------
  void _showSosDialog(String id) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title:
        const Text("SOS ACTIVE", style: TextStyle(color: Colors.redAccent)),
        content: const Text("Responders are tracking your location.",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('sos_triggers')
                  .doc(id)
                  .delete();
              Navigator.pop(context);
              setState(() => _sosActive = false);
            },
            child: const Text("CANCEL SOS",
                style: TextStyle(color: Colors.redAccent)),
          )
        ],
      ),
    );
  }

  /// ---------------- SOS BUTTON ----------------
  Widget sosButton() {
    Timer? timer;
    return GestureDetector(
      onTapDown: (_) {
        timer = Timer(const Duration(seconds: 3), () async {
          await _selectIncidentDetails();
          _triggerSos();
        });
      },
      onTapUp: (_) => timer?.cancel(),
      onTapCancel: () => timer?.cancel(),
      child: Container(
        height: 70,
        width: 70,
        decoration: BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.redAccent.withOpacity(0.5),
              blurRadius: 20,
            )
          ],
        ),
        child: const Icon(Icons.sos, color: Colors.white, size: 32),
      ),
    );
  }

  /// ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text("SOS AI")),
          backgroundColor: Colors.black,
          body: Center(
            child: _chatMessages.isEmpty
                ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                sosButton(),
                const SizedBox(height: 15),
                const Text("Hold 3 seconds to trigger SOS",
                    style: TextStyle(color: Colors.white70)),
              ],
            )
                : ListView.builder(
              itemCount: _chatMessages.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(_chatMessages[i]['message']!,
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ),

        /// -------- LOADING OVERLAY --------
        if (_loading)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            ),
          ),
      ],
    );
  }
}

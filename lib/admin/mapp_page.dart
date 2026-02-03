import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminMap extends StatefulWidget {
  const AdminMap({super.key});

  @override
  State<AdminMap> createState() => _AdminMapState();
}

class _AdminMapState extends State<AdminMap> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _shimmerController;
  bool _isAlarmPlaying = false;
  int _lastAlertCount = 0;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _stopAlarm();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ------------------- ALARM CONTROL -------------------
  void _playAlarm() async {
    if (_isAlarmPlaying) return;
    try {
      _isAlarmPlaying = true;
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('sounds/sirens.mp3')); // Ensure path in pubspec.yaml
    } catch (e) {
      debugPrint("Audio error: $e");
    }
  }

  void _stopAlarm() async {
    if (!_isAlarmPlaying) return;
    _isAlarmPlaying = false;
    await _audioPlayer.stop();
  }

  // ------------------- MAP CONTROLS -------------------
  void _zoomToLocation(double? lat, double? lng) {
    if (lat == null || lng == null) return;
    _mapController.move(LatLng(lat, lng), 17.5);
  }

  // ------------------- CALL USER -------------------
  Future<void> _callUser(Map<String, dynamic> data) async {
    final phone = data['phone'] ?? '';
    final userId = data['userId'];
    final name = data['name'] ?? 'User';
    if (userId == null || phone.isEmpty) return;

    // 1. Create a Firestore 'calls' document
    await FirebaseFirestore.instance.collection('calls').add({
      'calleeId': userId,
      'callerName': 'Admin',
      'status': 'ringing',
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Calling $name...')),
      );
    }

    // 2. Optional: Open device dialer
    final Uri callUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sos_triggers')
            .where('status', isNotEqualTo: 'resolved')
            .snapshots(),
        builder: (context, snapshot) {
          final sosDocs = snapshot.data?.docs ?? [];
          final int currentCount = sosDocs.length;

          // Alarm handling: play only once per new alert
          if (currentCount > _lastAlertCount) _playAlarm();
          if (currentCount == 0) _stopAlarm();
          _lastAlertCount = currentCount;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 25),
                  Expanded(
                    child: isDesktop
                        ? Row(
                      children: [
                        Expanded(flex: 3, child: _sweepWrapper(_buildMap(sosDocs))),
                        const SizedBox(width: 25),
                        Expanded(flex: 2, child: _sweepWrapper(_buildSosQueue(sosDocs))),
                      ],
                    )
                        : Column(
                      children: [
                        Expanded(flex: 2, child: _sweepWrapper(_buildMap(sosDocs))),
                        const SizedBox(height: 20),
                        Expanded(flex: 3, child: _sweepWrapper(_buildSosQueue(sosDocs))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ------------------- SHIMMER EFFECT WRAPPER -------------------
  Widget _sweepWrapper(Widget child) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Stack(
            children: [
              child,
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-2.0 + (_shimmerController.value * 4), -1.0),
                      end: Alignment(-1.0 + (_shimmerController.value * 4), 1.0),
                      colors: [
                        Colors.transparent,
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.15),
                        Colors.white.withOpacity(0.08),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 0.5, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ------------------- MAP -------------------
  Widget _buildMap(List<QueryDocumentSnapshot> sosDocs) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white10),
      ),
      child: FlutterMap(
        mapController: _mapController,
        options: const MapOptions(
          initialCenter: LatLng(14.5995, 120.9842),
          initialZoom: 13,
        ),
        children: [
          TileLayer(
            urlTemplate:
            'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            subdomains: const ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: sosDocs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final double? lat = double.tryParse(data['latitude'].toString());
              final double? lng = double.tryParse(data['longitude'].toString());
              if (lat == null || lng == null) return null;

              return Marker(
                point: LatLng(lat, lng),
                width: 50,
                height: 50,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.redAccent,
                  size: 40,
                ),
              );
            }).whereType<Marker>().toList(),
          ),
        ],
      ),
    );
  }

  // ------------------- SOS QUEUE -------------------
  Widget _buildSosQueue(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.shield_outlined, color: Colors.blueAccent, size: 30),
            SizedBox(height: 8),
            Text("NO ACTIVE ALERTS",
                style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return ListView(
      children: docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final double? lat = double.tryParse(data['latitude'].toString());
        final double? lng = double.tryParse(data['longitude'].toString());

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24, width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_rounded, color: Colors.redAccent, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['name'] ?? 'Unknown',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text(data['address'] ?? "Locating...",
                              style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.gps_fixed, color: Colors.blueAccent),
                      onPressed: () => _zoomToLocation(lat, lng),
                      tooltip: "Zoom to location",
                    ),
                    IconButton(
                      icon: const Icon(Icons.call, color: Colors.greenAccent),
                      onPressed: () => _callUser(data),
                      tooltip: "Call user",
                    ),
                    TextButton(
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('sos_triggers')
                            .doc(doc.id)
                            .update({'acknowledged': true});
                        if (docs.length == 1) _stopAlarm();
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.25),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        "ACK",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ------------------- HEADER -------------------
  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Command Center",
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          "Emergency Monitoring System • Satellite Live",
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }
}

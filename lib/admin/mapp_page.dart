import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added for Admin Tracking
import 'package:url_launcher/url_launcher.dart';

class AdminMap extends StatefulWidget {
  const AdminMap({super.key});

  @override
  State<AdminMap> createState() => _AdminMapState();
}

class _AdminMapState extends State<AdminMap> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _shimmerController;

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
    super.dispose();
  }

  // ------------------- MAP CONTROLS -------------------
  void _zoomToLocation(double? lat, double? lng) {
    if (lat == null || lng == null) return;
    _mapController.move(LatLng(lat, lng), 17.5);
  }

  // ------------------- CALL USER -------------------
  Future<void> _callUser(Map<String, dynamic> data) async {
    final phone = data['phone'] ?? '';
    final name = data['userName'] ?? 'User';

    if (phone.isEmpty) return;

    final Uri callUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Colors.transparent, // Let Dashboard background show through
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sos_triggers')
            .where('status', isNotEqualTo: 'resolved')
            .snapshots(),
        builder: (context, snapshot) {
          final sosDocs = snapshot.data?.docs ?? [];

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
                        Colors.white.withOpacity(0.03),
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.03),
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
          initialCenter: LatLng(14.5995, 120.9842), // Manila Default
          initialZoom: 13,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          ),
          MarkerLayer(
            markers: sosDocs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final double? lat = data['latitude'] is double ? data['latitude'] : double.tryParse(data['latitude'].toString());
              final double? lng = data['longitude'] is double ? data['longitude'] : double.tryParse(data['longitude'].toString());

              if (lat == null || lng == null) return null;

              final bool isAck = data['acknowledged'] == true;

              return Marker(
                point: LatLng(lat, lng),
                width: 60,
                height: 60,
                child: GestureDetector(
                  onTap: () => _zoomToLocation(lat, lng),
                  child: Icon(
                    Icons.location_on,
                    color: isAck ? Colors.greenAccent : Colors.redAccent,
                    size: 45,
                  ),
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
    final currentAdmin = FirebaseAuth.instance.currentUser;

    if (docs.isEmpty) {
      return Container(
        color: Colors.white.withOpacity(0.02),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, color: Colors.blueAccent, size: 30),
              SizedBox(height: 8),
              Text("STATION CLEAR", style: TextStyle(color: Colors.blueAccent, fontSize: 10, letterSpacing: 2)),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.white.withOpacity(0.02),
      child: ListView.builder(
        padding: const EdgeInsets.all(15),
        itemCount: docs.length,
        itemBuilder: (context, index) {
          final doc = docs[index];
          final data = doc.data() as Map<String, dynamic>;
          final bool isAck = data['acknowledged'] == true;

          final double? lat = data['latitude'] is double ? data['latitude'] : double.tryParse(data['latitude'].toString());
          final double? lng = data['longitude'] is double ? data['longitude'] : double.tryParse(data['longitude'].toString());

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isAck ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isAck ? Colors.greenAccent.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.emergency_outlined, color: isAck ? Colors.greenAccent : Colors.redAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['userName'] ?? 'Unknown User',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(isAck ? "Ack by: ${data['acknowledgedByEmail']}" : "Pending Response...",
                          style: TextStyle(color: isAck ? Colors.greenAccent : Colors.white38, fontSize: 10)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.gps_fixed, color: Colors.blueAccent, size: 20),
                  onPressed: () => _zoomToLocation(lat, lng),
                ),
                IconButton(
                  icon: const Icon(Icons.call, color: Colors.greenAccent, size: 20),
                  onPressed: () => _callUser(data),
                ),
                if (!isAck)
                  TextButton(
                    onPressed: () async {
                      await FirebaseFirestore.instance.collection('sos_triggers').doc(doc.id).update({
                        'acknowledged': true,
                        'acknowledgedByEmail': currentAdmin?.email ?? 'Unknown Admin',
                        'acknowledgedAt': FieldValue.serverTimestamp(),
                      });
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.blueAccent.withOpacity(0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("ACK", style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Satellite Monitor", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        Row(
          children: [
            Icon(Icons.circle, color: Colors.redAccent, size: 8),
            SizedBox(width: 5),
            Text("LIVE SIGNAL TRACKING", style: TextStyle(color: Colors.white38, fontSize: 8, letterSpacing: 1.5)),
          ],
        ),
      ],
    );
  }
}
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SosListPage extends StatelessWidget {
  const SosListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Transparent para makita ang Dashboard BG
      body: Stack(
        children: [
          // 1. SOS SPECIFIC BACKGROUND (Reddish Glow for Alerts)
          _buildSosBackground(),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- CUSTOM HEADER ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Active SOS Alerts",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 28,
                            letterSpacing: 1.2
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "LIVE EMERGENCY MONITORING",
                            style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // --- LIST AREA ---
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('sos_triggers')
                        .orderBy('time', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.gpp_good_rounded, color: Colors.greenAccent.withOpacity(0.1), size: 80),
                              const SizedBox(height: 15),
                              const Text("No Active Emergencies", style: TextStyle(color: Colors.white24, fontSize: 16)),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 15, 20, 120), // Padding para sa navbar
                        physics: const BouncingScrollPhysics(),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          return _buildEmergencyCard(data);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildSosBackground() {
    return Stack(
      children: [
        Container(color: Colors.black),
        Positioned(
          top: -100,
          left: -50,
          child: Container(
            width: 300, height: 300,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.08), blurRadius: 100, spreadRadius: 50)]
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyCard(Map<String, dynamic> data) {
    final Timestamp timestamp = data['time'] ?? Timestamp.now();
    final DateTime time = timestamp.toDate();
    final String formattedTime = DateFormat('hh:mm:ss a').format(time);
    final String dateLabel = DateFormat('MMM dd, yyyy').format(time);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.03),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.redAccent.withOpacity(0.2), width: 1.5),
            ),
            child: Row(
              children: [
                // Pulsing Icon Effect
                Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.emergency_rounded, color: Colors.redAccent, size: 30),
                    Container(
                      width: 45, height: 45,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['userId']?.toString().split('@')[0].toUpperCase() ?? "UNKNOWN USER",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time_filled_rounded, color: Colors.white38, size: 12),
                          const SizedBox(width: 5),
                          Text(
                            "$dateLabel • $formattedTime",
                            style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
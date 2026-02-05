import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_list.dart';

class AdminHome extends StatefulWidget {
  final Function(int)? onNavigate;
  const AdminHome({super.key, this.onNavigate});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  bool _isLocalMuted = false;

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

  // --- 🎨 BACKGROUND GLOWS (Same as AdminServices) ---
  Widget _buildBackgroundGlows() {
    return Stack(
      children: [
        Container(color: const Color(0xFF020617)), // Deep Midnight Base
        Positioned(
          top: -100,
          right: -50,
          child: _glow(Colors.blueAccent.withOpacity(0.15)),
        ),
        Positioned(
          bottom: -100,
          left: -50,
          child: _glow(Colors.indigoAccent.withOpacity(0.15)),
        ),
      ],
    );
  }

  Widget _glow(Color color) => Container(
    width: 400,
    height: 400,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: color,
          blurRadius: 120,
          spreadRadius: 50,
        )
      ],
    ),
  );

  // --- 💎 GLASS CONTAINER ---
  Widget _glassContainer({required Widget child, required Color borderColor, bool isBlinking = false}) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        double opacity = isBlinking ? (0.3 + (0.7 * (1.0 - _shimmerController.value))) : 1.0;

        return ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: borderColor.withOpacity(opacity),
                  width: 1.5,
                ),
                color: Colors.white.withOpacity(0.03),
              ),
              child: IntrinsicHeight(child: child),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark Base
      body: Stack(
        children: [
          _buildBackgroundGlows(), // Glow effects in the back
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sos_triggers')
                .where('status', isNotEqualTo: 'resolved')
                .snapshots(),
            builder: (context, snapshot) {
              final sosDocs = snapshot.data?.docs ?? [];
              final activeAlerts = sosDocs.where((d) => (d.data() as Map)['acknowledged'] != true).toList();

              return LayoutBuilder(
                builder: (context, constraints) {
                  bool isDesktop = constraints.maxWidth > 900;
                  return SafeArea(
                    child: Column(
                      children: [
                        if (activeAlerts.isNotEmpty) _buildTopSosNotification(activeAlerts, constraints.maxWidth),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 30 : 15),
                            child: isDesktop ? _buildDesktopLayout(sosDocs) : _buildMobileLayout(sosDocs),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // --- 📊 STAT CARDS LOGIC ---
  Widget _buildStatCard(String title, String coll, IconData icon, int idx, {bool isSOS = false}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(coll).snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        bool hasActive = count > 0;

        // Clean White Default
        Color borderCol = Colors.white.withOpacity(0.15);
        Color iconCol = Colors.white.withOpacity(0.7);
        bool blinking = false;

        if (hasActive) {
          if (isSOS) {
            borderCol = Colors.redAccent;
            iconCol = Colors.redAccent;
            blinking = true;
          } else {
            borderCol = Colors.greenAccent;
            iconCol = Colors.greenAccent;
          }
        }

        return _glassContainer(
          borderColor: borderCol,
          isBlinking: blinking,
          child: InkWell(
            onTap: () => idx != -1
                ? widget.onNavigate?.call(idx)
                : Navigator.push(context, MaterialPageRoute(builder: (_) => const UserListPage())),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: iconCol, size: 28),
                const SizedBox(height: 8),
                FittedBox(fit: BoxFit.scaleDown, child: Text(count.toString(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
                FittedBox(fit: BoxFit.scaleDown, child: Text(title.toUpperCase(), style: const TextStyle(color: Colors.white38, fontSize: 8, letterSpacing: 1.2, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- UI COMPONENTS ---
  Widget _buildDesktopLayout(List<QueryDocumentSnapshot> sosDocs) {
    return Row(children: [
      Expanded(flex: 3, child: SingleChildScrollView(child: Column(children: [const SizedBox(height: 20), _buildHeader(true), const SizedBox(height: 30), _buildResponsiveGrid(crossAxisCount: 2, ratio: 2.1)]))),
      const SizedBox(width: 30),
      Expanded(flex: 2, child: Column(children: [_buildSectionTitle("Live Monitoring"), Expanded(child: Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.01), borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.white.withOpacity(0.08))), child: _buildRecentSosList(sosDocs)))]))
    ]);
  }

  Widget _buildMobileLayout(List<QueryDocumentSnapshot> sosDocs) {
    return SingleChildScrollView(child: Column(children: [const SizedBox(height: 10), _buildHeader(false), const SizedBox(height: 20), _buildResponsiveGrid(crossAxisCount: 2, ratio: 1.35), const SizedBox(height: 30), _buildSectionTitle("Active Alerts"), _buildRecentSosList(sosDocs, shrinkWrap: true), const SizedBox(height: 80)]));
  }

  Widget _buildHeader(bool isDesktop) {
    return Row(children: [
      Icon(Icons.admin_panel_settings, color: Colors.white, size: isDesktop ? 40 : 32),
      const SizedBox(width: 15),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Admin Center", style: TextStyle(fontSize: isDesktop ? 32 : 26, fontWeight: FontWeight.bold, color: Colors.white)), const Text("LIVE COMMAND DASHBOARD", style: TextStyle(color: Colors.blueAccent, fontSize: 8, letterSpacing: 2))])),
      IconButton(icon: Icon(_isLocalMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white24), onPressed: () => setState(() => _isLocalMuted = !_isLocalMuted))
    ]);
  }

  Widget _buildResponsiveGrid({required int crossAxisCount, required double ratio}) {
    return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: crossAxisCount, crossAxisSpacing: 18, mainAxisSpacing: 18, childAspectRatio: ratio, children: _statCards());
  }

  List<Widget> _statCards() {
    return [
      _buildStatCard("Active SOS", "sos_triggers", Icons.warning_rounded, 1, isSOS: true),
      _buildStatCard("Requests", "service_requests", Icons.pending_actions, 2),
      _buildStatCard("Users", "users", Icons.people_rounded, -1),
      _buildStatCard("Alerts", "broadcasts", Icons.campaign_rounded, 3),
    ];
  }

  Widget _buildSectionTitle(String t) => Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(t.toUpperCase(), style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2))));

  Widget _buildRecentSosList(List<QueryDocumentSnapshot> docs, {bool shrinkWrap = false}) {
    if (docs.isEmpty) return const Center(child: Text("SYSTEMS CLEAR", style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 1.5)));
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      padding: const EdgeInsets.all(12),
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;
        bool isNotAck = data['acknowledged'] != true;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _glassContainer(
            borderColor: isNotAck ? Colors.redAccent : Colors.white12,
            isBlinking: isNotAck,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.emergency_recording_rounded, color: isNotAck ? Colors.redAccent : Colors.white70),
              title: Text(data['userName'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(data['phone'] ?? "No Contact", style: const TextStyle(color: Colors.white54, fontSize: 10)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopSosNotification(List<QueryDocumentSnapshot> activeDocs, double screenWidth) {
    final firstData = activeDocs.first.data() as Map<String, dynamic>;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(15)),
      child: Row(children: [
        const Icon(Icons.warning, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text("SOS: ${firstData['userName']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        TextButton(onPressed: () => widget.onNavigate?.call(1), child: const Text("VIEW", style: TextStyle(color: Colors.white, decoration: TextDecoration.underline)))
      ]),
    );
  }
}
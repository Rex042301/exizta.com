import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'user_list.dart';

class AdminHome extends StatefulWidget {
  final Function(int)? onNavigate;
  const AdminHome({super.key, this.onNavigate});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAlarmPlaying = false;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _playAlarm() async {
    if (!_isAlarmPlaying) {
      try {
        await _audioPlayer.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer.play(AssetSource('sounds/sirens.mp3'));
        if (mounted) setState(() => _isAlarmPlaying = true);
      } catch (e) {
        debugPrint("Audio Error: $e");
      }
    }
  }

  void _stopAlarm() async {
    if (_isAlarmPlaying) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _isAlarmPlaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildMainBackground(),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sos_triggers')
                .where('status', isNotEqualTo: 'resolved')
                .snapshots(),
            builder: (context, snapshot) {
              final sosDocs = snapshot.data?.docs ?? [];

              // --- PLAY / STOP ALARM LOGIC ---
              if (snapshot.hasData) {
                final hasGlobalSOS = sosDocs.isNotEmpty;

                if (hasGlobalSOS && !_isAlarmPlaying) {
                  _playAlarm(); // Play once when SOS appears
                } else if (!hasGlobalSOS && _isAlarmPlaying) {
                  _stopAlarm(); // Stop once when SOS clears
                }
              }

              return SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 1100) {
                      return _buildExpandedDesktopLayout(sosDocs);
                    } else {
                      return _buildMobileLayout(sosDocs);
                    }
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMainBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF020617), Colors.black],
        ),
      ),
    );
  }

  // --- GLASS CONTAINER WITH SHIMMER EFFECT ---
  Widget _glassContainer({
    required Widget child,
    required Color statusColor,
    bool isBlinking = false,
  }) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, childWidget) {
        double blink = isBlinking ? (0.4 + (0.5 * _shimmerController.value)) : 1.0;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.08 * blink),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: statusColor.withOpacity(isBlinking ? (0.5 * blink) : 0.2),
                    width: isBlinking ? 1.8 : 1.0,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment(-5.0 + (_shimmerController.value * 10), -1.2),
                    end: Alignment(-4.0 + (_shimmerController.value * 10), 1.2),
                    colors: [
                      Colors.transparent,
                      statusColor.withOpacity(0.05),
                      Colors.white.withOpacity(0.4),
                      statusColor.withOpacity(0.05),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.495, 0.5, 0.505, 1.0],
                  ),
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _statCards() {
    return [
      _buildStatCard("Active SOS", "sos_triggers", Icons.warning_rounded, 1, isEmergency: true),
      _buildStatCard("Requests", "service_requests", Icons.pending_actions, 2),
      _buildStatCard("Users", "users", Icons.people_rounded, -1),
      _buildStatCard("Announcements", "broadcasts", Icons.campaign_rounded, 3),
    ];
  }

  Widget _buildStatCard(String title, String coll, IconData icon, int idx, {bool isEmergency = false}) {
    return StreamBuilder<QuerySnapshot>(
      stream: isEmergency
          ? FirebaseFirestore.instance.collection(coll).where('status', isNotEqualTo: 'resolved').snapshots()
          : FirebaseFirestore.instance.collection(coll).snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        bool hasUpdate = count > 0;

        Color cardColor;
        if (isEmergency) {
          cardColor = hasUpdate ? Colors.redAccent : Colors.blueAccent;
        } else {
          cardColor = hasUpdate ? Colors.greenAccent : Colors.blueAccent;
        }

        return _glassContainer(
          statusColor: cardColor,
          isBlinking: hasUpdate && isEmergency,
          child: InkWell(
            onTap: () => idx != -1
                ? widget.onNavigate?.call(idx)
                : Navigator.push(context, MaterialPageRoute(builder: (_) => const UserListPage())),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: cardColor, size: 28),
                const SizedBox(height: 8),
                Text(
                  count.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                FittedBox(
                  child: Text(
                    title.toUpperCase(),
                    style: TextStyle(color: cardColor.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- MOBILE LAYOUT ---
  Widget _buildMobileLayout(List<QueryDocumentSnapshot> sosDocs) {
    return Column(
      children: [
        Padding(padding: const EdgeInsets.all(20), child: _buildHeader()),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            child: Column(
              children: [
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.2,
                  children: _statCards(),
                ),
                const SizedBox(height: 30),
                _buildSectionTitle("Active Alerts"),
                const SizedBox(height: 10),
                _buildRecentSosList(sosDocs, shrinkWrap: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- DESKTOP LAYOUT ---
  Widget _buildExpandedDesktopLayout(List<QueryDocumentSnapshot> sosDocs) {
    bool hasSOS = sosDocs.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 30),
          SizedBox(
            height: 140,
            child: Row(
              children: _statCards()
                  .map((card) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: card)))
                  .toList(),
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _glassContainer(
                    statusColor: hasSOS ? Colors.redAccent : Colors.blueAccent,
                    isBlinking: hasSOS,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle("Live SOS Monitor", onAction: () => widget.onNavigate?.call(1), actionLabel: "Open Map"),
                        const SizedBox(height: 20),
                        Expanded(child: _buildRecentSosList(sosDocs)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 30),
                Expanded(flex: 1, child: _buildSystemStatusPanel(hasSOS)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatusPanel(bool hasSOS) {
    return _glassContainer(
      statusColor: hasSOS ? Colors.redAccent : Colors.blueAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("SYSTEM STATUS", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 20),
          _statusRow("Database", "CONNECTED", Colors.greenAccent),
          _statusRow("Alarm", hasSOS ? "TRIGGERED" : "READY", hasSOS ? Colors.redAccent : Colors.white24),
          const Spacer(),
          Center(
            child: Text(
              hasSOS ? "🚨 SOS ACTIVE" : "STATION SECURED",
              textAlign: TextAlign.center,
              style: TextStyle(color: hasSOS ? Colors.redAccent : Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(String label, String val, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
        ],
      ),
    );
  }

  // --- SOS POP-UP ANIMATION LIST ---
  Widget _buildRecentSosList(List<QueryDocumentSnapshot> docs, {bool shrinkWrap = false}) {
    if (docs.isEmpty) return _buildEmptyState();

    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;

        double safeValue(double v) => v.clamp(0.0, 1.0);

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + index * 100),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            final opacity = safeValue(value);
            return Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: opacity,
                  child: _glassContainer(
                    statusColor: Colors.redAccent,
                    isBlinking: true,
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.emergency, color: Colors.redAccent, size: 20),
                      title: Text(data['userId']?.toString().split('@')[0].toUpperCase() ?? "USER",
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: Text(data['address'] ?? "Locating...",
                          style: const TextStyle(color: Colors.white38, fontSize: 10), maxLines: 1),
                      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 10),
                      onTap: () => widget.onNavigate?.call(1),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Admin Center", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            Text("COMMAND DASHBOARD", style: TextStyle(color: Colors.white54, fontSize: 8, letterSpacing: 1.2)),
          ],
        ),
        const Spacer(),
        if (_isAlarmPlaying)
          IconButton(onPressed: _stopAlarm, icon: const Icon(Icons.volume_off, color: Colors.redAccent, size: 20)),
      ],
    );
  }

  Widget _buildSectionTitle(String title, {VoidCallback? onAction, String? actionLabel}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        if (onAction != null)
          TextButton(
              onPressed: onAction,
              child: Text(actionLabel ?? "View All", style: const TextStyle(color: Colors.white70, fontSize: 11))),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, color: Colors.blueAccent, size: 30),
          SizedBox(height: 8),
          Text("NO PENDING ALERTS", style: TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

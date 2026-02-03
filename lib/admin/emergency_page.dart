import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';

class EmergencyPage extends StatefulWidget {
  const EmergencyPage({super.key});

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  // Position variables for the Moveable FAB
  Offset _fabPosition = const Offset(300, 600); // Default starting position

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _typeController.dispose();
    _contactController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // --- CRUD LOGIC ---
  Future<void> _saveEmergency({String? docId}) async {
    if (_typeController.text.isEmpty) return;
    final data = {
      'type': _typeController.text,
      'contact': _contactController.text,
      'description': _descController.text,
      'timestamp': FieldValue.serverTimestamp(),
    };
    if (docId == null) {
      await FirebaseFirestore.instance.collection('emergency_contacts').add(data);
    } else {
      await FirebaseFirestore.instance.collection('emergency_contacts').doc(docId).update(data);
    }
    _typeController.clear(); _contactController.clear(); _descController.clear();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteEmergency(String docId) async {
    bool confirm = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.delete_forever, color: Colors.redAccent, size: 40),
                    const SizedBox(height: 16),
                    const Text("Delete Info?", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL", style: TextStyle(color: Colors.white54))),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.3)),
                          child: const Text("DELETE"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ) ?? false;
    if (confirm) await FirebaseFirestore.instance.collection('emergency_contacts').doc(docId).delete();
  }

  // --- GLASS FORM ---
  void _showForm({String? docId, String? type, String? contact, String? desc}) {
    if (docId != null) {
      _typeController.text = type!; _contactController.text = contact!; _descController.text = desc!;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(docId == null ? "Add Emergency" : "Edit Emergency", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              TextField(controller: _typeController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Service Type", labelStyle: TextStyle(color: Colors.white54))),
              TextField(controller: _contactController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Hotline", labelStyle: TextStyle(color: Colors.white54))),
              TextField(controller: _descController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Notes", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => _saveEmergency(docId: docId), child: const Text("SAVE")),
            ],
          ),
        ),
      ),
    ).then((_) { _typeController.clear(); _contactController.clear(); _descController.clear(); });
  }

  Widget glassCard(String docId, String type, String contact, String desc) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(width: 1.5, color: Colors.white.withOpacity(0.4)),
              gradient: LinearGradient(
                begin: Alignment(-2.0 + (_shimmerController.value * 4), -1.0),
                end: Alignment(-1.0 + (_shimmerController.value * 4), 1.0),
                colors: [Colors.transparent, Colors.white.withOpacity(0.1), Colors.transparent],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.emergency, color: Colors.redAccent),
                      Row(
                        children: [
                          IconButton(icon: const Icon(Icons.edit_note, color: Colors.white70), onPressed: () => _showForm(docId: docId, type: type, contact: contact, desc: desc)),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _deleteEmergency(docId)),
                        ],
                      ),
                    ],
                  ),
                  Text(type, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(contact, style: const TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(color: Colors.white12),
                  Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.6))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("Emergency"), backgroundColor: Colors.transparent, elevation: 0),
      body: Stack(
        children: [
          // Background List
          Container(
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A0B0B), Colors.black], begin: Alignment.topCenter)),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('emergency_contacts').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 20, bottom: 100),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var d = snapshot.data!.docs[index];
                    return glassCard(d.id, d['type'], d['contact'], d['description']);
                  },
                );
              },
            ),
          ),

          // MOVEABLE GLASS FAB
          Positioned(
            left: _fabPosition.dx,
            top: _fabPosition.dy,
            child: Draggable(
              feedback: _buildFAB(),
              childWhenDragging: Container(),
              onDragEnd: (details) {
                setState(() {
                  // Snapping logic to keep it within view
                  double x = details.offset.dx.clamp(20.0, MediaQuery.of(context).size.width - 80.0);
                  double y = details.offset.dy.clamp(100.0, MediaQuery.of(context).size.height - 150.0);
                  _fabPosition = Offset(x, y);
                });
              },
              child: _buildFAB(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () => _showForm(),
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
            color: Colors.white.withOpacity(0.05),
            boxShadow: [BoxShadow(color: Colors.white10, blurRadius: 15)],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
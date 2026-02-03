import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';

class EvacuationPage extends StatefulWidget {
  const EvacuationPage({super.key});

  @override
  State<EvacuationPage> createState() => _EvacuationPageState();
}

class _EvacuationPageState extends State<EvacuationPage> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _rowFieldController = TextEditingController();
  final TextEditingController _columnFieldController = TextEditingController();

  // Position variables for Moveable FAB
  Offset _fabPosition = const Offset(0, 0);
  bool _isFABInitialized = false;

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
    _titleController.dispose();
    _rowFieldController.dispose();
    _columnFieldController.dispose();
    super.dispose();
  }

  // --- DELETE LOGIC ---
  Future<void> _deletePost(String docId) async {
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
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.delete_forever, color: Colors.redAccent, size: 40),
                    const SizedBox(height: 16),
                    const Text("Delete Card?", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL", style: TextStyle(color: Colors.white54))),
                        const SizedBox(width: 10),
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

    if (confirm) await FirebaseFirestore.instance.collection('evacuation_plans').doc(docId).delete();
  }

  // --- SAVE & UPDATE ---
  Future<void> _saveData({String? docId}) async {
    if (_titleController.text.isEmpty) return;
    final data = {
      'title': _titleController.text,
      'row_data': _rowFieldController.text,
      'column_data': _columnFieldController.text,
      'timestamp': FieldValue.serverTimestamp(),
    };
    if (docId == null) {
      await FirebaseFirestore.instance.collection('evacuation_plans').add(data);
    } else {
      await FirebaseFirestore.instance.collection('evacuation_plans').doc(docId).update(data);
    }
    _titleController.clear(); _rowFieldController.clear(); _columnFieldController.clear();
    if (mounted) Navigator.pop(context);
  }

  // --- GLASS FORM ---
  void _showForm({String? docId, String? title, String? row, String? col}) {
    if (docId != null) {
      _titleController.text = title!; _rowFieldController.text = row!; _columnFieldController.text = col!;
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
              Text(docId == null ? "Add Plan" : "Edit Plan", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              TextField(controller: _titleController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Title", labelStyle: TextStyle(color: Colors.white54))),
              TextField(controller: _rowFieldController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Location", labelStyle: TextStyle(color: Colors.white54))),
              TextField(controller: _columnFieldController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Instructions", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => _saveData(docId: docId), child: const Text("SAVE DATA")),
            ],
          ),
        ),
      ),
    ).then((_) {
      _titleController.clear(); _rowFieldController.clear(); _columnFieldController.clear();
    });
  }

  Widget glassPostCard(String docId, String title, String location, String instructions) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      Container(width: 40, height: 3, decoration: BoxDecoration(color: Colors.white54, borderRadius: BorderRadius.circular(10))),
                      Row(
                        children: [
                          IconButton(icon: const Icon(Icons.edit, color: Colors.white70, size: 18), onPressed: () => _showForm(docId: docId, title: title, row: location, col: instructions)),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), onPressed: () => _deletePost(docId)),
                        ],
                      ),
                    ],
                  ),
                  Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Divider(color: Colors.white12),
                  Text("📍 $location", style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text(instructions, style: TextStyle(color: Colors.white.withOpacity(0.6))),
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
    final double topPadding = MediaQuery.of(context).padding.top + kToolbarHeight;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Evacuation Centers", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Initialize FAB position to bottom right on first load
          if (!_isFABInitialized) {
            _fabPosition = Offset(constraints.maxWidth - 80, constraints.maxHeight - 100);
            _isFABInitialized = true;
          }

          return Stack(
            children: [
              // Main Content
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0D1B1E), Color(0xFF000000)],
                  ),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('evacuation_plans').orderBy('timestamp', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
                    return ListView.builder(
                      padding: EdgeInsets.only(top: topPadding + 20, bottom: 100),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var d = snapshot.data!.docs[index];
                        return glassPostCard(d.id, d['title'], d['row_data'], d['column_data']);
                      },
                    );
                  },
                ),
              ),

              // MOVEABLE SHINING GLASS FAB
              Positioned(
                left: _fabPosition.dx,
                top: _fabPosition.dy,
                child: Draggable(
                  feedback: _buildUnifiedGlassFAB(),
                  childWhenDragging: Container(),
                  onDragEnd: (details) {
                    setState(() {
                      // Clamp limits so it doesn't go off-screen or hide behind AppBar
                      double newX = details.offset.dx.clamp(10.0, constraints.maxWidth - 70.0);
                      double newY = details.offset.dy.clamp(topPadding, constraints.maxHeight - 80.0);
                      _fabPosition = Offset(newX, newY);
                    });
                  },
                  child: _buildUnifiedGlassFAB(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUnifiedGlassFAB() {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () => _showForm(),
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
            color: Colors.white.withOpacity(0.1),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.1),
                blurRadius: 15,
                spreadRadius: 1,
              )
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
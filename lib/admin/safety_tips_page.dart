import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';

class SafetyTipsPage extends StatefulWidget {
  const SafetyTipsPage({super.key});

  @override
  State<SafetyTipsPage> createState() => _SafetyTipsPageState();
}

class _SafetyTipsPageState extends State<SafetyTipsPage> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

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
    _contentController.dispose();
    super.dispose();
  }

  // --- SAVE & UPDATE LOGIC ---
  Future<void> _saveTip({String? docId}) async {
    if (_titleController.text.isEmpty) return;

    final data = {
      'title': _titleController.text,
      'content': _contentController.text,
      'timestamp': FieldValue.serverTimestamp(),
    };

    if (docId == null) {
      await FirebaseFirestore.instance.collection('safety_tips').add(data);
    } else {
      await FirebaseFirestore.instance.collection('safety_tips').doc(docId).update(data);
    }

    _titleController.clear();
    _contentController.clear();
    if (mounted) Navigator.pop(context);
  }

  // --- GLASS DELETE DIALOG ---
  Future<void> _deleteTip(String docId) async {
    bool confirm = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
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
                        const Text("Delete Tip?", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
            ),
          ),
        );
      },
    ) ?? false;

    if (confirm) await FirebaseFirestore.instance.collection('safety_tips').doc(docId).delete();
  }

  // --- GLASS FORM (ADD & EDIT) ---
  void _showTipForm({String? docId, String? title, String? content}) {
    if (docId != null) {
      _titleController.text = title!;
      _contentController.text = content!;
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
              Text(docId == null ? "Add Safety Tip" : "Edit Safety Tip", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              TextField(controller: _titleController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Tip Title", labelStyle: TextStyle(color: Colors.white54))),
              TextField(controller: _contentController, maxLines: 3, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Content", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _saveTip(docId: docId),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.withOpacity(0.3)),
                child: Text(docId == null ? "SAVE TIP" : "UPDATE TIP", style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      _titleController.clear();
      _contentController.clear();
    });
  }

  // --- CRYSTAL GLASS CARD ---
  Widget glassTipCard(String docId, String title, String content) {
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
                      const Icon(Icons.shield_outlined, color: Colors.greenAccent, size: 24),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_note, color: Colors.white70, size: 22),
                            onPressed: () => _showTipForm(docId: docId, title: title, content: content),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () => _deleteTip(docId),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 5),
                  Text(content, style: TextStyle(color: Colors.white.withOpacity(0.7), height: 1.4)),
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
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Safety Tips", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1B1E), Color(0xFF000000)],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('safety_tips').orderBy('timestamp', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.green));
            final docs = snapshot.data!.docs;
            return ListView.builder(
              padding: const EdgeInsets.only(top: 110, bottom: 100),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                return glassTipCard(docs[index].id, data['title'] ?? '', data['content'] ?? '');
              },
            );
          },
        ),
      ),
      floatingActionButton: _buildGlassFAB(),
    );
  }

  // --- UNIFIED SHINING GLASS FAB ---
  Widget _buildGlassFAB() {
    return FloatingActionButton(
      onPressed: () => _showTipForm(),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Shining Edge
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
          // Transparent center
          color: Colors.white.withOpacity(0.05),
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
    );
  }
}
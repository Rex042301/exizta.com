import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SafetyTipsPage extends StatefulWidget {
  const SafetyTipsPage({super.key});

  @override
  State<SafetyTipsPage> createState() => _SafetyTipsPageState();
}

class _SafetyTipsPageState extends State<SafetyTipsPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String? userRole;
  bool isLoading = true;
  String searchQuery = "";
  String selectedCategory = "General";

  final List<String> categories = ["General", "Flood", "Earthquake", "Fire", "First Aid"];

  @override
  void initState() {
    super.initState();
    _getUserRole();
  }

  Future<void> _getUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          userRole = doc.data()?['role'];
          isLoading = false;
        });
      }
    }
  }

  Future<void> _addTip() async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) return;
    await FirebaseFirestore.instance.collection('safety_tips').add({
      'title': _titleController.text,
      'content': _contentController.text,
      'category': selectedCategory,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _titleController.clear();
    _contentController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = userRole == 'admin';
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("SAFETY TIPS",
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          _buildBackgroundGlows(),
          isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
              : SafeArea(
            child: Column(children: [
              _buildSearchBar(),
              if (isAdmin) _buildAdminInput(),
              _buildCategoryChips(),
              Expanded(child: _buildTipsList(isAdmin)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: _buildGlassBox(
        child: TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Search safety guides...",
            hintStyle: TextStyle(color: Colors.white24),
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, color: Colors.cyanAccent),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          bool isSelected = categories[index] == selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(categories[index]),
              selected: isSelected,
              onSelected: (val) => setState(() => selectedCategory = categories[index]),
              selectedColor: Colors.cyanAccent,
              labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
              backgroundColor: Colors.white.withOpacity(0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdminInput() {
    return _buildGlassBox(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("ADMIN: POST SAFETY TIP",
            style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 15),
        _buildTextField(_titleController, "Tip Title", Icons.lightbulb_outline),
        const SizedBox(height: 10),
        _buildTextField(_contentController, "Detailed Instructions", Icons.article_outlined, maxLines: 3),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _addTip,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("SAVE TIP", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        )
      ]),
    );
  }

  Widget _buildTipsList(bool isAdmin) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('safety_tips')
          .where('category', isEqualTo: selectedCategory)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs.where((doc) {
          var d = doc.data() as Map<String, dynamic>;
          return d['title'].toString().toLowerCase().contains(searchQuery);
        }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text("No tips found for this category.", style: TextStyle(color: Colors.white24)));
        }

        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            return _buildGlassBox(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                iconColor: Colors.cyanAccent,
                collapsedIconColor: Colors.white24,
                title: Text(data['title'] ?? 'Safety Tip',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                children: [
                  const Divider(color: Colors.white10),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(data['content'] ?? '',
                        style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
                  ),
                  if (isAdmin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        onPressed: () => docs[index].reference.delete(),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- REUSABLE COMPONENTS ---
  Widget _buildGlassBox({required Widget child, EdgeInsets? margin, EdgeInsets? padding}) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.08))),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String lbl, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.cyanAccent, size: 18),
        labelText: lbl, labelStyle: const TextStyle(color: Colors.white38),
        filled: true, fillColor: Colors.black.withOpacity(0.3),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.cyanAccent)),
      ),
    );
  }

  Widget _buildBackgroundGlows() {
    return Stack(children: [
      Positioned(top: -100, left: -50, child: _glow(Colors.cyanAccent.withOpacity(0.1))),
      Positioned(bottom: -50, right: -100, child: _glow(Colors.blueAccent.withOpacity(0.05))),
    ]);
  }

  Widget _glow(Color color) => Container(width: 400, height: 400, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 200, spreadRadius: 50)]));
}
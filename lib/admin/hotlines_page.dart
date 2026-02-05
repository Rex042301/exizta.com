import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class HotlinesPage extends StatefulWidget {
  const HotlinesPage({super.key});

  @override
  State<HotlinesPage> createState() => _HotlinesPageState();
}

class _HotlinesPageState extends State<HotlinesPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String? userRole;
  bool isLoading = true;
  String searchQuery = "";

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

  // --- CRUD OPERATIONS ---

  Future<void> _addHotline() async {
    if (_nameController.text.isEmpty || _numberController.text.isEmpty) return;
    await FirebaseFirestore.instance.collection('hotlines').add({
      'name': _nameController.text,
      'number': _numberController.text,
      'category': _categoryController.text.isEmpty ? 'Emergency' : _categoryController.text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _nameController.clear();
    _numberController.clear();
    _categoryController.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _updateHotline(String docId, String name, String number, String category) async {
    await FirebaseFirestore.instance.collection('hotlines').doc(docId).update({
      'name': name,
      'number': number,
      'category': category,
    });
  }

  Future<void> _makeCall(String number) async {
    final Uri launchUri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  // --- EDIT DIALOG (GLASS MODAL) ---
  void _showEditSheet(String docId, Map<String, dynamic> currentData) {
    final editName = TextEditingController(text: currentData['name']);
    final editNumber = TextEditingController(text: currentData['number']);
    final editCategory = TextEditingController(text: currentData['category']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              const Text("EDIT HOTLINE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 20),
              _buildTextField(editName, "Agency Name", Icons.business),
              const SizedBox(height: 10),
              _buildTextField(editNumber, "Phone Number", Icons.phone, isPhone: true),
              const SizedBox(height: 10),
              _buildTextField(editCategory, "Category", Icons.label_important_outline),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    _updateHotline(docId, editName.text, editNumber.text, editCategory.text);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: const Text("UPDATE CHANGES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = userRole == 'admin';
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Emergency Hotlines", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          _buildBackgroundGlows(),
          isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
              : SafeArea(
            child: Column(
              children: [
                _buildSearchBar(),
                if (isAdmin) _buildAdminInput(),
                Expanded(child: _buildHotlineList(isAdmin)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 5),
      child: _buildGlassBox(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Search agencies or categories...",
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
            border: InputBorder.none,
            icon: const Icon(Icons.search, color: Colors.blueAccent, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminInput() {
    return _buildGlassBox(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("ADMIN: ADD NEW", style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 15),
          _buildTextField(_nameController, "Agency Name", Icons.business),
          const SizedBox(height: 10),
          _buildTextField(_numberController, "Phone Number", Icons.phone, isPhone: true),
          const SizedBox(height: 10),
          _buildTextField(_categoryController, "Category", Icons.category),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _addHotline,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("SAVE HOTLINE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHotlineList(bool isAdmin) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('hotlines').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return data['name'].toString().toLowerCase().contains(searchQuery) || data['category'].toString().toLowerCase().contains(searchQuery);
        }).toList();

        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            var docId = docs[index].id;
            return _buildGlassBox(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(data['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text("${data['category']} • ${data['number']}", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _actionButton(Icons.call, Colors.greenAccent, () => _makeCall(data['number'])),
                    if (isAdmin) ...[
                      _actionButton(Icons.edit_outlined, Colors.blueAccent, () => _showEditSheet(docId, data)),
                      _actionButton(Icons.delete_outline, Colors.redAccent.withOpacity(0.5), () => docs[index].reference.delete()),
                    ]
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _actionButton(IconData icon, Color color, VoidCallback onTap) {
    return IconButton(icon: Icon(icon, color: color, size: 20), onPressed: onTap);
  }

  Widget _buildGlassBox({required Widget child, EdgeInsets? margin, EdgeInsets? padding}) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.1))),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isPhone = false}) {
    return TextField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.blueAccent, size: 18),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.black.withOpacity(0.2),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent)),
      ),
    );
  }

  Widget _buildBackgroundGlows() {
    return Stack(children: [
      Positioned(top: -100, right: -50, child: _glow(Colors.blueAccent.withOpacity(0.15))),
      Positioned(bottom: -100, left: -50, child: _glow(Colors.indigoAccent.withOpacity(0.1))),
    ]);
  }

  Widget _glow(Color color) => Container(width: 400, height: 400, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 150, spreadRadius: 50)]));
}
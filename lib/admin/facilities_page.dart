import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class FacilitiesPage extends StatefulWidget {
  const FacilitiesPage({super.key});

  @override
  State<FacilitiesPage> createState() => _FacilitiesPageState();
}

class _FacilitiesPageState extends State<FacilitiesPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _typeController = TextEditingController(); // e.g., Hospital, Police
  final TextEditingController _contactController = TextEditingController();
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

  Future<void> _addFacility() async {
    if (_nameController.text.isEmpty || _typeController.text.isEmpty) return;
    await FirebaseFirestore.instance.collection('facilities').add({
      'name': _nameController.text,
      'type': _typeController.text,
      'contact': _contactController.text,
      'status': 'Operational',
      'createdAt': FieldValue.serverTimestamp(),
    });
    _nameController.clear();
    _typeController.clear();
    _contactController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = userRole == 'admin';
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("FACILITIES",
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16, letterSpacing: 3)),
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
              ? const Center(child: CircularProgressIndicator(color: Colors.indigoAccent))
              : SafeArea(
            child: Column(children: [
              _buildSearchBar(),
              if (isAdmin) _buildAdminInput(),
              Expanded(child: _buildFacilityList(isAdmin)),
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
            hintText: "Search hospitals, stations...",
            hintStyle: TextStyle(color: Colors.white24),
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, color: Colors.indigoAccent),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminInput() {
    return _buildGlassBox(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("ADMIN: REGISTER FACILITY",
            style: TextStyle(color: Colors.indigoAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 15),
        _buildTextField(_nameController, "Facility Name", Icons.account_balance_rounded),
        const SizedBox(height: 10),
        _buildTextField(_typeController, "Type (e.g. Hospital)", Icons.category_rounded),
        const SizedBox(height: 10),
        _buildTextField(_contactController, "Contact Info", Icons.phone_android_rounded),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _addFacility,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("SAVE FACILITY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        )
      ]),
    );
  }

  Widget _buildFacilityList(bool isAdmin) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('facilities').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs.where((doc) {
          var d = doc.data() as Map<String, dynamic>;
          return d['name'].toString().toLowerCase().contains(searchQuery) ||
              d['type'].toString().toLowerCase().contains(searchQuery);
        }).toList();

        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            return _buildGlassBox(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.indigoAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(_getIcon(data['type']), color: Colors.indigoAccent),
                ),
                title: Text(data['name'] ?? 'Facility', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text("${data['type']} • ${data['status']}", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                trailing: isAdmin
                    ? IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    onPressed: () => docs[index].reference.delete())
                    : const Icon(Icons.arrow_forward_ios, color: Colors.white10, size: 14),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getIcon(String? type) {
    String t = type?.toLowerCase() ?? "";
    if (t.contains("hospital") || t.contains("clinic")) return Icons.local_hospital_rounded;
    if (t.contains("police")) return Icons.local_police_rounded;
    if (t.contains("fire")) return Icons.fire_truck_rounded;
    return Icons.location_city_rounded;
  }

  // --- REUSABLE COMPONENTS ---
  Widget _buildGlassBox({required Widget child, EdgeInsets? margin, EdgeInsets? padding}) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1))),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String lbl, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.indigoAccent, size: 18),
        labelText: lbl, labelStyle: const TextStyle(color: Colors.white38),
        filled: true, fillColor: Colors.black.withOpacity(0.3),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.indigoAccent)),
      ),
    );
  }

  Widget _buildBackgroundGlows() {
    return Stack(children: [
      Positioned(top: -100, left: -50, child: _glow(Colors.indigoAccent.withOpacity(0.12))),
      Positioned(bottom: -100, right: -50, child: _glow(Colors.purpleAccent.withOpacity(0.08))),
    ]);
  }

  Widget _glow(Color color) => Container(width: 400, height: 400, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 150, spreadRadius: 50)]));
}
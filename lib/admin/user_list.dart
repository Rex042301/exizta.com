import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  String _search = "";
  String _filter = "all"; // all / new / active / blocked
  final ScrollController _horizontalScroll = ScrollController();

  // --- CSV Export ---
  Future<void> _exportUsersToCSV() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection("users").get();
      List<List<dynamic>> rows = [];

      // Header
      rows.add(["ID", "Name", "Email", "Phone", "Role", "Status"]);

      for (var i = 0; i < snapshot.docs.length; i++) {
        var data = snapshot.docs[i].data();
        rows.add([
          (i + 1).toString(),
          data["name"] ?? "N/A",
          data["email"] ?? "N/A",
          data["phone"] ?? "N/A",
          data["role"] ?? "user",
          data["status"] ?? "active",
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/Aiper_User_Database.csv";
      final file = File(path);
      await file.writeAsString(csvData);

      await Share.shareXFiles([XFile(path)], text: 'Aiper User Database Export');
    } catch (e) {
      debugPrint("Export Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildMainBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.2),
                          ),
                          child: Column(
                            children: [
                              _searchBar(),
                              _filterButtons(),
                              Expanded(
                                child: Scrollbar(
                                  controller: _horizontalScroll,
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    controller: _horizontalScroll,
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: SizedBox(
                                      width: 1100,
                                      child: Column(
                                        children: [
                                          _tableHeader(),
                                          Expanded(child: _buildUserList()),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainBackground() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black, Color(0xFF001A33), Colors.black],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        _buildGlowCircle(top: -100, left: -50, color: Colors.blueAccent),
        _buildGlowCircle(bottom: 100, right: -80, color: Colors.indigoAccent),
      ],
    );
  }

  Widget _buildGlowCircle({double? top, double? bottom, double? left, double? right, required Color color}) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 350,
        height: 350,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 120, spreadRadius: 60)],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("User Database",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 1)),
              Text("MANAGE ACCOUNTS & ROLES",
                  style: TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: _exportUsersToCSV,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.3))),
              child: const Icon(Icons.file_download_outlined, color: Colors.greenAccent, size: 20),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05)))),
      child: TextField(
        style: const TextStyle(color: Colors.white),
        onChanged: (v) => setState(() => _search = v.toLowerCase()),
        decoration: InputDecoration(
          hintText: "Search by ID, Name, or Email...",
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: Colors.blueAccent, size: 20),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.blueAccent)),
        ),
      ),
    );
  }

  Widget _filterButtons() {
    final filters = ["all", "new", "active", "blocked"];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: filters.map((f) {
          final isSelected = _filter == f;
          final label = f.toUpperCase();
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              onPressed: () => setState(() => _filter = f),
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected ? Colors.blueAccent : Colors.white12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              ),
              child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontSize: 12)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.2), width: 1)),
      ),
      child: const Row(
        children: [
          _ExcelCell("ID", 70, isHeader: true),
          _ExcelCell("NAME", 180, isHeader: true),
          _ExcelCell("EMAIL", 250, isHeader: true),
          _ExcelCell("PHONE", 150, isHeader: true),
          _ExcelCell("ROLE", 120, isHeader: true),
          _ExcelCell("STATUS", 120, isHeader: true),
          _ExcelCell("ACTIONS", 110, isHeader: true),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("users").orderBy("createdAt", descending: false).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
        }

        final allDocs = snapshot.data!.docs;

        final filteredDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data["status"] ?? "active").toString().toLowerCase();
          final name = (data["name"] ?? "").toString().toLowerCase();
          final email = (data["email"] ?? "").toString().toLowerCase();
          final idNum = (allDocs.indexOf(doc) + 1).toString();

          final matchesFilter = _filter == "all" || status == _filter || (_filter == "new" && (data["createdAt"] == null));
          final matchesSearch = name.contains(_search) || email.contains(_search) || idNum == _search;

          return matchesFilter && matchesSearch;
        }).toList();

        if (filteredDocs.isEmpty) {
          return const Center(child: Text("No users found", style: TextStyle(color: Colors.white60)));
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            int id = allDocs.indexOf(doc) + 1;
            return _excelRow(data, id, doc.id);
          },
        );
      },
    );
  }

  Widget _excelRow(Map<String, dynamic> data, int id, String uid) {
    final status = (data["status"] ?? "active").toString().toLowerCase();
    final isNew = data["createdAt"] == null; // highlight new users
    return Container(
      decoration: BoxDecoration(
        color: isNew ? Colors.blueAccent.withOpacity(0.1) : Colors.transparent,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          _ExcelCell("#${id.toString().padLeft(2, '0')}", 70, color: Colors.blueAccent, isBold: true),
          _ExcelCell(data["name"] ?? "N/A", 180),
          _ExcelCell(data["email"] ?? "N/A", 250),
          _ExcelCell(data["phone"] ?? "N/A", 150),
          _ExcelCell(data["role"]?.toString().toUpperCase() ?? "USER", 120),
          _excelWidgetCell(_statusBadge(status), 120),
          _excelWidgetCell(_actionButtons(uid, data), 110),
        ],
      ),
    );
  }

  Widget _excelWidgetCell(Widget child, double width) {
    return Container(
      width: width,
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.white.withOpacity(0.2)))),
      child: child,
    );
  }

  Widget _statusBadge(String status) {
    final isBlocked = status == "blocked";
    final color = isBlocked ? Colors.redAccent : Colors.greenAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }

  Widget _actionButtons(String uid, Map<String, dynamic> data) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.edit_note_rounded, color: Colors.blueAccent, size: 22),
          onPressed: () => _showEditDialog(uid, data),
        ),
        const SizedBox(width: 5),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
          onPressed: () => _confirmDelete(uid),
        ),
      ],
    );
  }

  // --- Dialogs ---
  void _showEditDialog(String uid, Map<String, dynamic> data) {
    // Implement your edit dialog here
  }

  void _confirmDelete(String uid) {
    // Implement your delete confirmation dialog here
  }

  Widget _dialogField(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }

  Widget _dialogDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _ExcelCell extends StatelessWidget {
  final String text;
  final double width;
  final bool isHeader;
  final Color? color;
  final bool isBold;

  const _ExcelCell(this.text, this.width, {this.isHeader = false, this.color, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.white.withOpacity(0.2)))),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color ?? (isHeader ? Colors.white38 : Colors.white.withOpacity(0.7)),
          fontWeight: isHeader || isBold ? FontWeight.w900 : FontWeight.normal,
          fontSize: isHeader ? 10 : 13,
          letterSpacing: isHeader ? 1 : 0,
        ),
      ),
    );
  }
}

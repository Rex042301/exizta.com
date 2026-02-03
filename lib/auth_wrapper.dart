import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'main.dart'; // HomePage design
import 'user/user_dashboard.dart';
import 'admin/admin_dashboard.dart'; // create this page for admin users

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // ⏳ Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ✅ Logged in
        if (snapshot.hasData) {
          final user = snapshot.data!;

          // Use FutureBuilder to fetch role from Firestore
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get(),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Colors.black,
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (!roleSnapshot.hasData || !roleSnapshot.data!.exists) {
                return const Scaffold(
                  backgroundColor: Colors.black,
                  body: Center(child: Text(
                    "User data not found",
                    style: TextStyle(color: Colors.white),
                  )),
                );
              }

              final role = roleSnapshot.data!.get('role') ?? 'user';

              if (role == 'admin') {
                return const AdminDashboardPage(); // redirect admin
              } else {
                return const UserDashboardPage(userRole: '',); // regular user
              }
            },
          );
        }

        // ❌ Not logged in → show HomePage (login/register)
        return const HomePage();
      },
    );
  }
}

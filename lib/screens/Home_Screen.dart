import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mycalapp/screens/Account_screen.dart';
import 'package:mycalapp/screens/data_kalori.dart';
import 'package:mycalapp/screens/Cek_BMI.dart';
import 'package:mycalapp/screens/konsumsi_kalori.dart';

class Home_Screen extends StatelessWidget {
  const Home_Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF3EDF7), // ✅ Background warna F3EDF7
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // **Gambar Background dengan Teks di Dalamnya**
          Stack(
            children: [
              SizedBox(
                height: 320,
                width: double.infinity,
                child: Image.asset(
                  'assets/bghome.png',
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                left: 20,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // **Display the current user's name**
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseAuth.instance.currentUser != null
                          ? FirebaseFirestore.instance
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser!.uid)
                              .get()
                          : Future.value(null),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return CircularProgressIndicator();
                        } else if (snapshot.hasError) {
                          return Text('Error loading user data');
                        } else if (!snapshot.hasData ||
                            !snapshot.data!.exists) {
                          return Text('Selamat Datang, User');
                        } else {
                          var userData =
                              snapshot.data!.data() as Map<String, dynamic>;
                          return Text(
                            'Selamat Datang, ${userData['name'] ?? 'User'}',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Apa kamu sudah menjaga asupan kalorimu?',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              // **Tombol Menu Bulat di Kiri Atas**
              Positioned(
                top: 40, // Posisi dekat status bar
                left: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white, // Latar belakang putih
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.menu, color: Colors.black),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MenuPage()),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          // **Teks "Apa yang Kamu Cari?" di Tengah**
          Center(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Text(
                'Apa yang Kamu Cari?',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // **List Menu dengan Border Hitam 1**
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(20),
              children: [
                buildMenuItem(
                  title: 'Cek Konsumsi Kalori',
                  subtitle: 'Pantau Asupan Kalorimu',
                  imageAsset: 'assets/bg1.png',
                  onTap: () {
                    String userId =
                        FirebaseAuth.instance.currentUser?.uid ?? '';
                    if (userId.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                CalorieScreen(userId: userId)),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('User tidak ditemukan')),
                      );
                    }
                  },
                  titleFontSize: 16,
                  subtitleFontSize: 14,
                ),
                buildMenuItem(
                  title: 'Cek BMI',
                  subtitle: 'Cek Postur Tubuh Kamu',
                  imageAsset: 'assets/bg2.png',
                  onTap: () {
                    String userId =
                        FirebaseAuth.instance.currentUser?.uid ?? '';
                    if (userId.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => BMIScreen(userId: userId)),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('User tidak ditemukan')),
                      );
                    }
                  },
                  titleFontSize: 16,
                  subtitleFontSize: 14,
                ),
                buildMenuItem(
                  title: 'Data Kalori',
                  subtitle:
                      'Informasi Kalori, berdasarkan apa yang kamu makan.',
                  imageAsset: 'assets/bg3.png',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => DataKalori()),
                    );
                  },
                  titleFontSize: 16,
                  subtitleFontSize: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // **Widget Menu Item dengan Border Hitam 1 & Gambar di Kanan**
  Widget buildMenuItem({
    required String title,
    required String subtitle,
    required String imageAsset,
    required VoidCallback onTap,
    double titleFontSize = 14,
    double subtitleFontSize = 12,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border:
            Border.all(color: Colors.black, width: 1), // Border hitam tebal 1
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
      ),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: titleFontSize, // Custom font size for title
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: subtitleFontSize, // Custom font size for subtitle
          ),
        ),
        trailing: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child:
              Image.asset(imageAsset, width: 70, height: 70, fit: BoxFit.cover),
        ),
        onTap: onTap,
      ),
    );
  }
}

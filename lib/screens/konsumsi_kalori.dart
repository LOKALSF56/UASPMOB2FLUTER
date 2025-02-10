import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mycalapp/screens/add_breakfast_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mycalapp/screens/add_lunch_screen.dart';
import 'package:mycalapp/screens/add_dinner_screen.dart';
import 'package:mycalapp/screens/add_snack_screen.dart';

class CalorieScreen extends StatefulWidget {
  final String userId;
  const CalorieScreen({required this.userId, Key? key}) : super(key: key);

  @override
  _CalorieScreenState createState() => _CalorieScreenState();
}

String getCurrentUserId() {
  return FirebaseAuth.instance.currentUser?.uid ?? "";
}

class _CalorieScreenState extends State<CalorieScreen> {
  List<Map<String, dynamic>> calorieRecords = [];
  int totalCaloriesToday = 0;
  int sarapan = 0;
  int makanSiang = 0;
  int makanMalam = 0;
  int cemilan = 0;

  @override
  void initState() {
    super.initState();
    fetchCalorieData();
  }

  Future<void> tambahHariKonsumsiBaru() async {
    try {
      var calorieCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('calories');

      // Ambil jumlah hari terakhir yang ada
      var snapshot = await calorieCollection
          .orderBy('days', descending: true)
          .limit(1)
          .get();
      int lastDay = snapshot.docs.isNotEmpty ? snapshot.docs.first['days'] : 0;

      // Tambah dokumen baru dengan semua nilai 0
      await calorieCollection.add({
        'days': lastDay + 1,
        'totalcal': 0,
        'sarapan': 0,
        'mknsiang': 0,
        'mknmalam': 0,
        'cemilan': 0,
      });

      // Perbarui UI
      setState(() {
        totalCaloriesToday = 0;
        sarapan = 0;
        makanSiang = 0;
        makanMalam = 0;
        cemilan = 0;
        calorieRecords.add({
          'days': lastDay + 1,
          'totalcal': 0,
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Hari konsumsi baru ditambahkan!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menambahkan hari baru: $e")));
    }
  }

  Future<void> fetchCalorieData() async {
    var calorieCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('calories')
        .orderBy('days', descending: false)
        .limit(7);

    var snapshot = await calorieCollection.get();
    var data = snapshot.docs.map((doc) => doc.data()).toList();

    if (data.isNotEmpty) {
      setState(() {
        calorieRecords = data;
        sarapan = data.last['sarapan'] ?? 0;
        makanSiang = data.last['mknsiang'] ?? 0;
        makanMalam = data.last['mknmalam'] ?? 0;
        cemilan = data.last['cemilan'] ?? 0;

        // Hitung total kalori berdasarkan nilai kategori makanan
        totalCaloriesToday = sarapan + makanSiang + makanMalam + cemilan;

        // Perbarui totalcal di Firestore
        FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('calories')
            .doc(snapshot.docs.last.id) // Ambil dokumen terakhir (hari terbaru)
            .update({'totalcal': totalCaloriesToday});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cek Konsumsi Kalori"),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1386E4),
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Jumlah Kalori Hari Ini",
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    Text("$totalCaloriesToday/2000",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold)),
                    Text(
                        "Sarapan: $sarapan Kalori\nMakan Siang: $makanSiang Kalori\nMakan Malam: $makanMalam Kalori\nCemilan: $cemilan Kalori",
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 150,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  int index = value.toInt();
                                  if (index >= 0 &&
                                      index < calorieRecords.length) {
                                    return Text(
                                      "Day ${calorieRecords[index]['days']}",
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: calorieRecords.map((entry) {
                                return FlSpot(
                                  entry['days'].toDouble(), // X-Axis: Hari
                                  entry['totalcal']
                                      .toDouble(), // Y-Axis: Total Kalori
                                );
                              }).toList(),
                              isCurved: true,
                              color: Colors.white,
                              dotData: FlDotData(show: true),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildAddDayTile(),
              _buildFoodCategory("Sarapan", sarapan, Icons.free_breakfast,
                  TambahSarapanScreen(userId: getCurrentUserId())),
              _buildFoodCategory("Makan Siang", makanSiang, Icons.lunch_dining,
                  TambahMknsiangScreen(userId: getCurrentUserId())),
              _buildFoodCategory("Makan Malam", makanMalam, Icons.dining,
                  TambahDinnerScreen(userId: getCurrentUserId())),
              _buildFoodCategory("Cemilan", cemilan, Icons.food_bank,
                  TambahCemilanScreen(userId: getCurrentUserId())),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFoodCategory(
      String title, int calories, IconData icon, Widget page) {
    return Card(
      elevation: 4,
      child: ListTile(
        leading: Icon(icon, size: 40, color: Colors.blue),
        title: Text(title, style: const TextStyle(fontSize: 18)),
        subtitle: Text("$calories Kalori"),
        trailing: IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.blue, size: 30),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => page),
            );
            // 🔄 Refresh data setelah kembali dari halaman lain
            fetchCalorieData();
          },
        ),
      ),
    );
  }

  Widget _buildAddDayTile() {
    return Card(
      elevation: 4,
      child: ListTile(
        leading:
            const Icon(Icons.calendar_today, size: 40, color: Colors.green),
        title: const Text("Tambah Hari Konsumsi",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: const Text("Mulai hari baru dengan kalori 0"),
        trailing: IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.green, size: 30),
          onPressed: tambahHariKonsumsiBaru,
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mycalapp/screens/Tambah_BMI.dart';

class BMIScreen extends StatefulWidget {
  final String userId;
  const BMIScreen({required this.userId, Key? key}) : super(key: key);

  @override
  _BMIScreenState createState() => _BMIScreenState();
}

class _BMIScreenState extends State<BMIScreen> {
  double lastBMI = 0.0;
  String bmiCategory = "";
  List<Map<String, dynamic>> bmiRecords = [];

  @override
  void initState() {
    super.initState();
    fetchBMIData();
  }

  Future<void> fetchBMIData() async {
    var bmiCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('bmi_records')
        .orderBy('days', descending: false) // Urutkan berdasarkan hari

        .limit(7);

    var snapshot = await bmiCollection.get();
    var data = snapshot.docs.map((doc) => doc.data()).toList();

    if (data.isNotEmpty) {
      setState(() {
        lastBMI = data.last['score'] ?? 0.0; // Ambil skor BMI terbaru
        bmiRecords = data;
        bmiCategory = getBMICategory(lastBMI);
      });
    }
  }

  String getBMICategory(double bmi) {
    if (bmi < 18.5) return "Underweight";
    if (bmi < 24.9) return "Normal";
    if (bmi < 29.9) return "Overweight";
    return "Obese";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cek BMI"),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
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
                  const Text("Skor BMI terakhir",
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  Text(lastBMI.toStringAsFixed(1),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold)),
                  Text(bmiCategory,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 16)),
                  SizedBox(height: 10),
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
                                var dayValues =
                                    bmiRecords.map((e) => e['days']).toList();
                                if (dayValues.contains(index)) {
                                  return Text(
                                    index.toString(), // Menampilkan angka hari
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  );
                                }
                                return Text('');
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: bmiRecords.map((entry) {
                              return FlSpot(
                                entry['days']
                                    .toDouble(), // X-Axis berdasarkan hari (sekarang angka)
                                entry['score']
                                    .toDouble(), // Y-Axis berdasarkan BMI score
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1386E4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BMIPage()),
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundImage: AssetImage('assets/user.png'),
                      ),
                      const SizedBox(width: 10),
                      const Text("Perbarui BMI",
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                    ],
                  ),
                  const Icon(Icons.add, color: Colors.white, size: 28),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

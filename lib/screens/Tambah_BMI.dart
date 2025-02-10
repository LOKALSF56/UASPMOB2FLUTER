import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BMIPage extends StatefulWidget {
  @override
  _BMIPageState createState() => _BMIPageState();
}

class _BMIPageState extends State<BMIPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late String _userId;
  String _gender = 'Laki-laki';
  int _age = 0;
  String _measurementSystem = 'Metric';
  double _bmiScore = 22.3;
  String _bmiStatus = 'Normal';
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId') ?? '';

    if (_userId.isEmpty) {
      print('Error: _userId kosong');
      return;
    }

    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(_userId).get();

    if (userDoc.exists) {
      setState(() {
        _age = userDoc['age'];
        _gender = userDoc['gender'];
        _ageController.text = _age.toString();
      });
    } else {
      print('Error: Dokumen pengguna tidak ditemukan');
    }
  }

  void _calculateBMI() {
    double weight = double.tryParse(_weightController.text) ?? 0;
    double height = double.tryParse(_heightController.text) ?? 0;
    int age = int.tryParse(_ageController.text) ?? 0;

    if (_measurementSystem == 'Imperial') {
      weight = weight * 0.453592;
      height = height * 2.54;
    }

    if (height > 0) {
      double heightInMeter = height / 100;
      double newBMI = weight / (heightInMeter * heightInMeter);
      _updateBMIStatus(newBMI, age, _gender);
      setState(() {
        _bmiScore = newBMI;
      });
    }
  }

  Widget _buildDropdownField({
    required String value,
    required List<String> items,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.black, width: 1.5),
            color: Colors.transparent,
          ),
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  if (label == 'Standard Ukuran') {
                    _measurementSystem = newValue!;
                  } else if (label == 'Jenis Kelamin') {
                    _gender = newValue!;
                  }
                  _calculateBMI();
                });
              },
              hint: Text(label),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String unit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.black, width: 1.5),
            color: Colors.transparent,
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              suffixText: unit,
              suffixStyle: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            style: TextStyle(fontSize: 16),
            onChanged: (value) => _calculateBMI(),
          ),
        ),
      ],
    );
  }

  void _updateBMIStatus(double bmi, int age, String gender) {
    setState(() {
      if (bmi < 18.5) {
        _bmiStatus = 'Underweight';
      } else if (bmi < 25) {
        _bmiStatus = 'Normal';
      } else if (bmi < 30) {
        _bmiStatus = 'Overweight';
      } else {
        _bmiStatus = 'Obese';
      }

      // Adjust BMI status based on age and gender
      if (age < 18) {
        _bmiStatus = 'Underweight';
      } else if (age > 65) {
        _bmiStatus = 'Overweight';
      }

      if (gender == 'Perempuan') {
        _bmiStatus += '';
      } else {
        _bmiStatus += '';
      }
    });
  }

  Future<void> _saveBMI() async {
    if (_userId.isEmpty) {
      print('Error: _userId kosong, tidak dapat menyimpan BMI');
      return;
    }

    QuerySnapshot snapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('bmi_records')
        .get();

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('bmi_records')
        .add({
      'score': _bmiScore,
      'days': snapshot.size + 1,
      'timestamp': FieldValue.serverTimestamp(),
    });

    print("Skor BMI berhasil ditambahkan");
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tambahkan BMI')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDropdownField(
                    value: _measurementSystem,
                    items: ['Metric', 'Imperial'],
                    label: 'Standard Ukuran',
                  ),
                  SizedBox(height: 15),
                  _buildDropdownField(
                    value: _gender,
                    items: ['Laki-laki', 'Perempuan'],
                    label: 'Jenis Kelamin',
                  ),
                  SizedBox(height: 15),
                  _buildInputField(
                    controller: _ageController,
                    label: 'Usia',
                    unit: 'Tahun',
                  ),
                  SizedBox(height: 15),
                  _buildInputField(
                    controller: _weightController,
                    label: 'Berat Badan',
                    unit: _measurementSystem == 'Metric' ? 'KG' : 'LB',
                  ),
                  SizedBox(height: 10),
                  _buildInputField(
                    controller: _heightController,
                    label: 'Tinggi Badan',
                    unit: _measurementSystem == 'Metric' ? 'CM' : 'IN',
                  ),
                  SizedBox(height: 20),
                  Column(
                    children: [
                      Text(
                        'Skor BMI',
                        style: TextStyle(fontSize: 18),
                      ),
                      Text(
                        _bmiScore.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _bmiStatus,
                        style: TextStyle(
                          fontSize: 24,
                          color: _getStatusColor(),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 30),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1386E4),
                padding: EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: _saveBMI,
              child: Text(
                'Simpan BMI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (_bmiStatus) {
      case 'Underweight':
        return Colors.blue;
      case 'Normal':
        return Colors.green;
      case 'Overweight':
        return Colors.orange;
      case 'Obese':
        return Colors.red;
      default:
        return Colors.black;
    }
  }
}

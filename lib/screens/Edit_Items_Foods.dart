import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditItemFoods extends StatefulWidget {
  final QueryDocumentSnapshot foodData;

  EditItemFoods({required this.foodData});

  @override
  _EditItemFoodsState createState() => _EditItemFoodsState();
}

class _EditItemFoodsState extends State<EditItemFoods> {
  File? _image;
  final picker = ImagePicker();
  late TextEditingController nameController;
  late TextEditingController caloriesController;
  late TextEditingController qtyController;
  late TextEditingController unitController;
  String imageUrl = ""; // URL gambar makanan

  @override
  void initState() {
    super.initState();
    // Isi field dengan data yang akan diedit
    nameController = TextEditingController(text: widget.foodData["name"]);
    caloriesController =
        TextEditingController(text: widget.foodData["calories"].toString());
    qtyController =
        TextEditingController(text: widget.foodData["qty"].toString());
    unitController = TextEditingController(text: widget.foodData["unit"]);
    imageUrl = widget.foodData["profileImage"];
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _updateData() async {
    if (nameController.text.isEmpty ||
        caloriesController.text.isEmpty ||
        qtyController.text.isEmpty ||
        unitController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Mohon isi semua field")),
      );
      return;
    }

    // Upload gambar baru jika ada perubahan
    if (_image != null) {
      Reference ref = FirebaseStorage.instance
          .ref()
          .child("foods/${DateTime.now().millisecondsSinceEpoch}.jpg");
      await ref.putFile(_image!);
      imageUrl = await ref.getDownloadURL(); // Perbarui URL gambar
    }

    // Update data di Firestore
    await FirebaseFirestore.instance
        .collection("foods")
        .doc(widget.foodData.id)
        .update({
      "profileImage": imageUrl,
      "name": nameController.text,
      "calories": int.parse(caloriesController.text),
      "qty": int.parse(qtyController.text),
      "unit": unitController.text,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Item berhasil diperbarui!")),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Edit Item")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 80,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: _image != null
                      ? FileImage(_image!)
                      : NetworkImage(imageUrl) as ImageProvider,
                  child: _image == null && imageUrl.isEmpty
                      ? Icon(Icons.camera_alt, size: 40, color: Colors.black54)
                      : null,
                ),
              ),
            ),
            SizedBox(height: 20),
            Text("Nama Item", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Color(0xFF1386E4)),
                ),
              ),
            ),
            SizedBox(height: 10),
            Text("Jumlah Kalori",
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            TextField(
              controller: caloriesController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Color(0xFF1386E4)),
                ),
              ),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Text("Jumlah Sajian",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 140),
                Text("/ Porsi", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Color(0xFF1386E4)),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: unitController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Color(0xFF1386E4)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: ElevatedButton(
                  onPressed: _updateData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF1386E4),
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text("Simpan Perubahan",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 20)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

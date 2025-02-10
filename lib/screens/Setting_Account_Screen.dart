import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  _ProfilPageState createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController oldPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();

  String gender = "Laki-laki";
  bool isPasswordHidden = true;
  File? _image;
  String? imageUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFromSharedPreferences();
    _fetchUserData();
  }

  Future<void> _loadFromSharedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      nameController.text = prefs.getString("name") ?? "";
      ageController.text = prefs.getString("age") ?? "";
      emailController.text = prefs.getString("email") ?? "";
      gender = prefs.getString("gender") ?? "Laki-laki";
      imageUrl = prefs.getString("profileImage");
    });
  }

  Future<void> _fetchUserData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userData = await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .get();

        if (userData.exists) {
          setState(() {
            nameController.text = userData["name"];
            ageController.text = userData["age"];
            emailController.text = userData["email"];
            imageUrl = userData["profileImage"];
            gender = userData["gender"] ?? "Laki-laki";
          });
        }
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  Future<void> _updatePassword() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (oldPasswordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Masukkan password lama")),
        );
        return;
      }

      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: oldPasswordController.text,
      );
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPasswordController.text);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password berhasil diperbarui!")),
      );
    } on FirebaseAuthException catch (e) {
      String message = "Gagal memperbarui password";
      if (e.code == 'wrong-password') {
        message = "Password lama salah";
      } else if (e.code == 'requires-recent-login') {
        message = "Silakan login ulang";
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Terjadi kesalahan")),
      );
    }
  }

  Future<void> _updateEmail() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Pastikan email baru berbeda dengan email lama
      if (emailController.text == user.email) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Email baru sama dengan email lama")),
        );
        return;
      }

      // Reautentikasi pengguna sebelum memperbarui email
      if (oldPasswordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Masukkan password lama untuk mengubah email")),
        );
        return;
      }

      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: oldPasswordController.text,
      );
      await user.reauthenticateWithCredential(credential);

      // Perbarui email di Firebase Authentication
      await user.verifyBeforeUpdateEmail(emailController.text);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "Email berhasil diperbarui! Silakan verifikasi email baru.")),
      );

      // Perbarui email di Firestore
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .update({"email": emailController.text});

      // Perbarui email di SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString("email", emailController.text);
    } on FirebaseAuthException catch (e) {
      String message = "Gagal memperbarui email";
      if (e.code == 'wrong-password') {
        message = "Password lama salah";
      } else if (e.code == 'requires-recent-login') {
        message = "Silakan login ulang";
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Terjadi kesalahan")),
      );
    }
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  Future<String?> _uploadImage(File image) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child("profile_pictures")
          .child("${DateTime.now()}.jpg");
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Error uploading image: $e");
      return null;
    }
  }

  Future<void> _updateProfile() async {
    if (nameController.text.isEmpty ||
        ageController.text.isEmpty ||
        emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Semua kolom wajib diisi")));
      return;
    }

    if (newPasswordController.text.isNotEmpty &&
        oldPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Masukkan password lama untuk mengubah")));
      return;
    }

    bool confirm = await _showConfirmationDialog();
    if (!confirm) return;

    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (_image != null) {
        imageUrl = await _uploadImage(_image!);
      }

      // Perbarui email jika diubah
      if (emailController.text != user.email) {
        await _updateEmail();
      }

      // Perbarui data di Firestore
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .update({
        "name": nameController.text,
        "age": ageController.text,
        "gender": gender,
        "email": emailController.text,
        "profileImage": imageUrl ?? "",
      });

      // Perbarui password jika diubah
      if (newPasswordController.text.isNotEmpty) {
        await _updatePassword();
      }

      // Simpan ke SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString("name", nameController.text);
      await prefs.setString("age", ageController.text);
      await prefs.setString("gender", gender);
      await prefs.setString("email", emailController.text);
      if (imageUrl != null) await prefs.setString("profileImage", imageUrl!);

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profil berhasil diperbarui!")));
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Terjadi kesalahan, coba lagi")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Konfirmasi"),
            content: const Text("Anda yakin mau merubah profil?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Batal"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Ya"),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profil")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  backgroundColor: Colors.grey[300],
                  radius: 50,
                  backgroundImage: _image != null
                      ? FileImage(_image!)
                      : (imageUrl != null && imageUrl!.isNotEmpty
                          ? NetworkImage(imageUrl!)
                          : null),
                  child:
                      _image == null && (imageUrl == null || imageUrl!.isEmpty)
                          ? Icon(Icons.camera_alt, size: 40, color: Colors.grey)
                          : null,
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField(nameController, "Nama Lengkap"),
              _buildGenderDropdown(),
              _buildTextField(ageController, "Umur", isNumber: true),
              _buildTextField(emailController, "Email"),
              _buildTextField(oldPasswordController, "Password Lama",
                  isPassword: true),
              _buildTextField(newPasswordController, "Password Baru",
                  isPassword: true),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Ubah Profil",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: gender,
      items: ["Laki-laki", "Perempuan"]
          .map((value) => DropdownMenuItem(value: value, child: Text(value)))
          .toList(),
      onChanged: (newValue) => setState(() => gender = newValue!),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isPassword = false, bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? isPasswordHidden : false,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          hintText: label,
          filled: true,
          fillColor: Colors.grey[200],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(isPasswordHidden
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => isPasswordHidden = !isPasswordHidden),
                )
              : null,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mycalapp/screens/Home_Screen.dart';
import 'package:mycalapp/screens/Register_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class Login_Screen extends StatefulWidget {
  const Login_Screen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<Login_Screen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<String> _uploadImageToStorage(String userId, String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$userId.jpg');
      await file.writeAsBytes(response.bodyBytes);

      final ref =
          FirebaseStorage.instance.ref().child('profile_images/$userId.jpg');
      await ref.putFile(file);

      return await ref.getDownloadURL();
    } catch (e) {
      print("Gagal mengunggah foto profil: $e");
      return imageUrl; // Jika gagal, tetap gunakan URL asli Facebook
    }
  }

  Future<void> _saveUserToFirestore(User user, String? imageUrl) async {
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final userData = await userRef.get();

    if (!userData.exists) {
      await userRef.set({
        'name': user.displayName ?? "User",
        'email': user.email,
        'gender': "", // Bisa diisi nanti oleh user
        'age': "", // Bisa diisi nanti oleh user
        'profileImage': imageUrl ?? "",
      });
    }
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    String? userId = prefs.getString('userId'); // Ambil userId

    if (isLoggedIn && userId != null) {
      print("User ID: $userId"); // Debugging
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => Home_Screen()),
      );
    }
  }

  Future<void> _saveLoginState(bool isLoggedIn, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', isLoggedIn);
    await prefs.setString('userId', userId);
  }

  Future<void> _loginWithEmail() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError("Kolom wajib diisi");
      return;
    }

    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      await _saveUserToFirestore(userCredential.user!, null);

      _saveLoginState(true, userCredential.user!.uid);

      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => Home_Screen()));
    } catch (e) {
      _showError("Email atau password salah");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);

      // Cek apakah foto profil ada
      String? profileImageUrl = userCredential.user?.photoURL;

      // Jika ada foto profil, upload ke Firebase Storage dan dapatkan URL baru
      if (profileImageUrl != null) {
        profileImageUrl = await _uploadImageToStorage(
            userCredential.user!.uid, profileImageUrl);
      }

      // Simpan data pengguna ke Firestore
      await _saveUserToFirestore(userCredential.user!, profileImageUrl);

      _saveLoginState(true, userCredential.user!.uid);

      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => Home_Screen()));
    } catch (e) {
      _showError(e.toString());
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loginWithFacebook() async {
    setState(() => _isLoading = true);
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.success) {
        final AccessToken? accessToken = result.accessToken;
        if (accessToken != null) {
          final OAuthCredential credential =
              FacebookAuthProvider.credential(accessToken.tokenString);
          final userCredential =
              await FirebaseAuth.instance.signInWithCredential(credential);

          final user = userCredential.user!;
          String? profileImageUrl = user.photoURL; // URL dari Facebook

          // Jika foto profil ada, upload ke Firebase Storage dan ambil URL baru
          if (profileImageUrl != null) {
            profileImageUrl =
                await _uploadImageToStorage(user.uid, profileImageUrl);
          }

          // Simpan data pengguna ke Firestore
          await _saveUserToFirestore(user, profileImageUrl);

          _saveLoginState(true, user.uid);

          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => Home_Screen()));
        }
      } else {
        _showError("Login Facebook gagal: ${result.message}");
      }
    } catch (e) {
      _showError(e.toString());
    }
    setState(() => _isLoading = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("MyCal",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            SizedBox(height: 30),
            Text("Login",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: "Email",
                filled: true,
                fillColor: Colors.grey[200],
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                hintText: "Password",
                filled: true,
                fillColor: Colors.grey[200],
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
            ),
            SizedBox(height: 20),
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _loginWithEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(vertical: 15),
                      textStyle: TextStyle(fontSize: 18),
                    ),
                    child: Center(
                        child: Text("Masuk",
                            style: TextStyle(color: Colors.white))),
                  ),
            SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegisterPage()),
                );
              },
              child: Center(
                child: Text(
                  "Belum Punya Akun? Daftar Disini",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ),
            ),
            SizedBox(height: 20),
            Center(child: Text("Masuk Dengan Akun Ini")),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _loginWithGoogle,
                  child: Image.asset('assets/google.png', width: 50),
                ),
                SizedBox(width: 20),
                GestureDetector(
                  onTap: _loginWithFacebook,
                  child: Image.asset('assets/facebook.png', width: 50),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

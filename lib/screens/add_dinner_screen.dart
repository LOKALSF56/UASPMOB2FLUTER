import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TambahDinnerScreen extends StatefulWidget {
  final String userId;
  const TambahDinnerScreen({required this.userId, Key? key}) : super(key: key);

  @override
  _TambahDinnerScreenState createState() => _TambahDinnerScreenState();
}

class _TambahDinnerScreenState extends State<TambahDinnerScreen> {
  List<Map<String, dynamic>> selectedFoods = [];
  int totalCalories = 0;

  void fetchFoods() async {
    var snapshot = await FirebaseFirestore.instance.collection('foods').get();
    var foods = snapshot.docs.map((doc) {
      var data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'] as String,
        'calories': (data['calories'] as num).toInt(),
        'profileImage': data['profileImage'] as String,
        'unit': data['unit'] as String,
        'qty': (data['qty'] as num).toInt(),
      };
    }).toList();
    showFoodSelectionDialog(foods);
  }

  void showFoodSelectionDialog(List<Map<String, dynamic>> foods) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView.builder(
          itemCount: foods.length,
          itemBuilder: (context, index) {
            var food = foods[index];
            return ListTile(
              leading:
                  Image.network(food['profileImage'], width: 40, height: 40),
              title: Text(food['name']),
              subtitle: Text("${food['calories']} Kalori per ${food['unit']}"),
              onTap: () {
                addFoodToList(food);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  void addFoodToList(Map<String, dynamic> food) {
    setState(() {
      selectedFoods.add({
        'id': food['id'],
        'name': food['name'],
        'calories': (food['calories'] as num).toInt(),
        'unit': food['unit'],
        'quantity': 1,
        'profileImage': food['profileImage'],
      });
      totalCalories += (food['calories'] as num).toInt();
    });
  }

  void editFoodQuantity(int index) {
    TextEditingController controller = TextEditingController(
        text: selectedFoods[index]['quantity'].toString());
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Ubah Porsi"),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Jumlah"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                int newQuantity = int.tryParse(controller.text) ?? 1;
                setState(() {
                  int oldCalories = selectedFoods[index]['calories'] *
                      selectedFoods[index]['quantity'];
                  selectedFoods[index]['quantity'] = newQuantity;
                  int newCalories =
                      selectedFoods[index]['calories'] * newQuantity;

                  totalCalories = totalCalories - oldCalories + newCalories;
                });
                Navigator.pop(context);
              },
              child: const Text("Simpan"),
            ),
          ],
        );
      },
    );
  }

  void removeFood(int index) {
    setState(() {
      totalCalories -= ((selectedFoods[index]['calories'] as num) *
              (selectedFoods[index]['quantity'] as num))
          .toInt();

      selectedFoods.removeAt(index);
    });
  }

  void saveCalories() async {
    var userDoc =
        FirebaseFirestore.instance.collection('users').doc(widget.userId);
    var calorieCollection = userDoc.collection('calories');

    var snapshot = await calorieCollection
        .orderBy('days', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      // Jika sudah ada data, update "mknmalam" pada hari terakhir
      snapshot.docs.first.reference.update({'mknmalam': totalCalories});
    } else {
      // Jika subkoleksi "calories" belum ada, buat hari pertama
      await calorieCollection.add({
        'days': 1,
        'totalcal': totalCalories, // Tambahkan total kalori awal
        'sarapan': 0,
        'mknsiang': 0,
        'mknmalam': totalCalories, // Set mknmalam dengan nilai yang dimasukkan
        'cemilan': 0,
      });
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tambah Makan Malam")),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                ...selectedFoods.map((food) {
                  int index = selectedFoods.indexOf(food);
                  return Card(
                    color: const Color(0xFF1386E4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ListTile(
                      leading: Image.network(food['profileImage'],
                          width: 40, height: 40),
                      title: Text(food['name'],
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        "${food['quantity']} ${food['unit']} \n${food['calories'] * food['quantity']} Kalori",
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white),
                            onPressed: () => editFoodQuantity(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.white),
                            onPressed: () => removeFood(index),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                GestureDetector(
                  onTap: fetchFoods,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: const Color(0xFF1386E4), width: 2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.add, color: Color(0xFF1386E4), size: 32),
                        Text("Tambah Item",
                            style: TextStyle(color: Color(0xFF1386E4))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text("Total Asupan",
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.normal)),
              Text("$totalCalories Kalori",
                  style: const TextStyle(
                      fontSize: 26,
                      color: Color.fromARGB(255, 0, 0, 0),
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1386E4),
                  minimumSize: const Size(400, 50), // Lebar 200, tinggi 50
                ),
                onPressed: saveCalories,
                child: const Text(
                  "Simpan",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

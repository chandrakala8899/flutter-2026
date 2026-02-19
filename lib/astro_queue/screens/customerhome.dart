import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/api_service.dart';
import 'package:flutter_learning/astro_queue/model/enumsession.dart';
import 'package:flutter_learning/astro_queue/model/usermodel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sessionscreen.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  UserModel? currentUser;
  List<UserModel> practitioners = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserAndData();
  }

  Future<void> _loadUserAndData() async {
    final user = await ApiService.getAllUsers();
    setState(() {
      currentUser = user;
      isLoading = false;
    });

    // TODO: Fetch real practitioners from API
    setState(() {
      practitioners = [
        UserModel.mock(id: "p1", name: "Dr. Smith", role: Role.practitioner),
        UserModel.mock(id: "p2", name: "Dr. John", role: Role.practitioner),
        UserModel.mock(id: "p3", name: "Dr. Sharma", role: Role.practitioner),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Welcome, ${currentUser?.name ?? 'Customer'}!"),
        backgroundColor: const Color(0xff2575FC),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserAndData,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: practitioners.length,
                itemBuilder: (context, index) {
                  final practitioner = practitioners[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xff2575FC),
                        child: Text(
                          practitioner.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        practitioner.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: const Text("Astrologer"),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff2575FC),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () => _startConsultation(practitioner),
                        child: const Text("Consult"),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _startConsultation(UserModel practitioner) {
    final session = SessionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      customer: UserModel.mock(
        id: currentUser!.userId.toString(),
        name: currentUser!.name,
        role: Role.customer,
      ),
      practitioner: practitioner,
      status: SessionStatus.created,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessionScreen(
          isCustomer: true,
          session: session,
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await ApiService.logout();
    Navigator.pushReplacementNamed(context, '/login');
  }
}

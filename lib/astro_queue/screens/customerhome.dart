import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/api_service.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';
import 'package:flutter_learning/astro_queue/model/enumsession.dart';
import 'package:flutter_learning/astro_queue/model/session_request_model.dart';
import 'package:flutter_learning/astro_queue/model/usermodel.dart';
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
  DateTime? selectedStartTime;
  DateTime? selectedEndTime;

  @override
  void initState() {
    super.initState();
    _loadUserAndData();
  }

  Future<void> _loadUserAndData() async {
    try {
      setState(() => isLoading = true);

      final loggedUser = await ApiService.getLoggedInUser();
      final allUsers = await ApiService.getAllUsers();

      final practitionerList =
          allUsers.where((user) => user.roleEnum == Role.practitioner).toList();

      setState(() {
        currentUser = loggedUser;
        practitioners = practitionerList;
        isLoading = false;
      });
    } catch (e) {
      print("Error loading data: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _startConsultation(UserModel practitioner) async {
    if (currentUser == null) return;

    // Pick start time
    selectedStartTime =
        await _showOrangeDateTimePicker(initialTime: DateTime.now());
    if (selectedStartTime == null) return;

    setState(() {}); // Update UI to show times in card

    // Pick end time
    selectedEndTime = await _showOrangeDateTimePicker(
      initialTime: selectedStartTime!.add(const Duration(minutes: 30)),
      minTime: selectedStartTime!,
    );
    if (selectedEndTime == null) return;

    setState(() {}); // Update UI

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.orange[50],
        title: const Text("Confirm Consultation",
            style: TextStyle(color: Colors.orange)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Practitioner: ${practitioner.name}",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Column(
                children: [
                  Text(
                      "Start: ${selectedStartTime!.toLocal().toString().split('.')[0]}"),
                  Text(
                      "End: ${selectedEndTime!.toLocal().toString().split('.')[0]}"),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[500],
              foregroundColor: Colors.white,
            ),
            onPressed: () => _confirmSession(practitioner),
            child: const Text("Confirm & Create"),
          ),
        ],
      ),
    );
  }

  Future<DateTime?> _showOrangeDateTimePicker({
    required DateTime initialTime,
    DateTime? minTime,
  }) async {
    DateTime firstDate = minTime ?? DateTime.now();

    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialTime,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
          primaryColor: Colors.orange,
        ),
        child: child!,
      ),
    );
    if (pickedDate == null) return null;

    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialTime),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
          primaryColor: Colors.orange,
        ),
        child: child!,
      ),
    );
    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  Future<void> _confirmSession(UserModel practitioner) async {
    Navigator.pop(context);

    final request = ConsultationSessionRequest(
      customerId: currentUser!.userId!,
      consultantId: practitioner.userId!,
      startDate: selectedStartTime!,
      endDate: selectedEndTime!,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Creating session...")),
    );

    final sessionResponse = await ApiService.createSession(request: request);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sessionResponse != null
              ? "✅ Session created! ID: ${sessionResponse.sessionId}"
              : "✅ Request sent successfully to ${practitioner.name}"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Navigate with real session data or fallback
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionScreen(
            isCustomer: true,
            session: sessionResponse ??
                ConsultationSessionResponse(
                  sessionId: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  status: SessionStatus.waiting,
                  customer: SimpleUser(
                      id: currentUser!.userId, name: currentUser!.name),
                  consultant: SimpleUser(
                      id: practitioner.userId, name: practitioner.name),
                  startedAt: selectedStartTime,
                  completedAt: selectedEndTime,
                ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Welcome, ${currentUser?.name ?? 'Customer'}!",
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange[600],
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : RefreshIndicator(
              onRefresh: _loadUserAndData,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: practitioners.length,
                itemBuilder: (context, index) {
                  final practitioner = practitioners[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Practitioner info + button
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundColor: Colors.orange[400],
                                child: Text(
                                  practitioner.name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      practitioner.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const Text(
                                      "Astrologer Practitioner",
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange[500],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                onPressed: () =>
                                    _startConsultation(practitioner),
                                icon: const Icon(Icons.schedule, size: 18),
                                label: const Text("Consult Now"),
                              ),
                            ],
                          ),
                          // Selected times display
                          if (selectedStartTime != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange[200]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.access_time,
                                          color: Colors.orange[700], size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Selected Times:",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange[800],
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _TimeChip(
                                    label: "Start",
                                    time: selectedStartTime!,
                                    icon: Icons.play_arrow,
                                  ),
                                  const SizedBox(height: 4),
                                  _TimeChip(
                                    label: "End",
                                    time: selectedEndTime ?? DateTime.now(),
                                    icon: Icons.stop,
                                    isPending: selectedEndTime == null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
}

// Time chip widget
class _TimeChip extends StatelessWidget {
  final String label;
  final DateTime time;
  final IconData icon;
  final bool isPending;

  const _TimeChip({
    required this.label,
    required this.time,
    required this.icon,
    this.isPending = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isPending ? Colors.grey[100] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPending ? Colors.grey : Colors.orange[300]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isPending ? Colors.grey : Colors.orange),
          const SizedBox(width: 8),
          Text(
            "$label: ${time.toLocal().toString().split('.')[0]}",
            style: TextStyle(
              fontSize: 12,
              fontWeight: isPending ? FontWeight.normal : FontWeight.w600,
              color: isPending ? Colors.grey[600] : Colors.orange[800],
            ),
          ),
        ],
      ),
    );
  }
}

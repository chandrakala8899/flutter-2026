import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/api_service.dart';
import 'package:flutter_learning/astro_queue/model/enumsession.dart';
import 'package:flutter_learning/astro_queue/model/usermodel.dart';
import 'package:http/http.dart' as http;
import 'sessionscreen.dart';

class PractitionerHome extends StatefulWidget {
  const PractitionerHome({super.key});

  @override
  State<PractitionerHome> createState() => _PractitionerHomeState();
}

class _PractitionerHomeState extends State<PractitionerHome> {
  UserModel? currentUser;
  List<SessionModel> queue = [];
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserAndQueue();
  }

  /// ✅ FIXED: Real API calls with proper endpoints
  Future<void> _loadUserAndQueue() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // ✅ 1. Get CURRENT logged-in user (SharedPreferences)
      final loggedUser =
          await ApiService.getAllUsers(); // Returns single logged user
      if (!mounted) return;

      if (loggedUser == null) {
        throw Exception("No logged-in user found. Please login again.");
      }

      if (mounted) {
        setState(() {
          currentUser = loggedUser;
        });
      }

      print("✅ Logged user: ${loggedUser.name} (ID: ${loggedUser.userId})");

      // ✅ 2. Get practitioner's sessions directly (most likely endpoint)
      final sessionsData = await _getPractitionerQueue(loggedUser.userId!);

      print("✅ Sessions loaded: ${sessionsData.length}");

      // ✅ 3. Convert raw session data to SessionModel
      final sessions = sessionsData.map((sessionData) {
        return SessionModel(
          id: sessionData['id']?.toString() ??
              's${DateTime.now().millisecondsSinceEpoch}',
          customer: UserModel(
            userId:
                int.tryParse(sessionData['customerId']?.toString() ?? '0') ?? 0,
            name: sessionData['customerName']?.toString() ?? 'Unknown Customer',
            roleEnum: Role.practitioner, // Fixed: use Role enum
          ),
          practitioner: loggedUser,
          status: _parseSessionStatus(
              sessionData['status']?.toString() ?? 'waiting'),
        );
      }).toList();

      if (mounted) {
        setState(() {
          queue = sessions;
          isLoading = false;
        });
      }
    } catch (e) {
      print("❌ Error loading queue: $e");

      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = "Cannot load queue: ${e.toString()}";
        });
      }
    }
  }

  /// ✅ FIXED: Use correct endpoint (add this to your backend)
  Future<List<Map<String, dynamic>>> _getPractitionerQueue(
      int practitionerId) async {
    try {
      print(
          "🔗 Calling: ${ApiService.baseUrl}/api/practitioner/$practitionerId/queue");

      final response = await http.get(
        Uri.parse(
            "${ApiService.baseUrl}/api/practitioner/$practitionerId/queue"),
        headers: {
          "Content-Type": "application/json",
          // Add auth header if needed
          // "Authorization": "Bearer ${await ApiService.getAuthToken()}"
        },
      ).timeout(const Duration(seconds: 15));

      print("📡 Status: ${response.statusCode}");
      print("📦 Response: ${response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        print("❌ API returned ${response.statusCode}");
        return []; // Empty queue
      }
    } catch (e) {
      print("❌ Network error: $e");
      return []; // Empty queue on network failure
    }
  }

  SessionStatus _parseSessionStatus(String status) {
    switch (status.toLowerCase()) {
      case 'waiting':
      case 'pending':
        return SessionStatus.waiting;
      case 'active':
      case 'in_progress':
        return SessionStatus.inProgress;
      case 'completed':
      case 'done':
        return SessionStatus.completed;
      default:
        return SessionStatus.waiting;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "My Queue (${queue.length}) - ${currentUser?.name ?? 'Loading...'}",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
            onPressed: _loadUserAndQueue,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          // ✅ Error banner with retry
          if (errorMessage != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade300, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: Colors.orange.shade700, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          errorMessage!,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Check your internet connection",
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _loadUserAndQueue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Retry"),
                  ),
                ],
              ),
            ),

          Expanded(
            child: isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.green),
                        SizedBox(height: 20),
                        Text("Loading your queue...",
                            style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    color: Colors.green,
                    onRefresh: _loadUserAndQueue,
                    child: queue.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: queue.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final session = queue[index];
                              return _buildSessionCard(session);
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadUserAndQueue,
        backgroundColor: Colors.green.shade600,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  // ... rest of your existing methods (_buildEmptyState, _buildSessionCard, etc. remain same)
  Widget _buildEmptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.queue_outlined, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 24),
              const Text(
                "Your queue is empty",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                "No customers waiting right now.\nPull to refresh or wait for bookings.",
                style: TextStyle(color: Colors.grey[600], height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _loadUserAndQueue,
                icon: const Icon(Icons.refresh),
                label: const Text("Refresh Queue"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      );

  String _getStatusMessage(SessionStatus status) {
    switch (status) {
      case SessionStatus.waiting:
        return "Ready to start";
      case SessionStatus.inProgress:
        return "In progress";
      case SessionStatus.completed:
        return "Session finished";
      default:
        return "Ready to start";
    }
  }

  Widget _buildSessionCard(SessionModel session) {
    return Card(
      elevation: 6,
      shadowColor: Colors.green.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openSession(session),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🌟 Enhanced Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade400, Colors.orange.shade500],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    session.customer.name.isNotEmpty
                        ? session.customer.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.customer.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Session #${session.id}",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade400,
                                Colors.green.shade500
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            session.status.name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _getStatusMessage(session.status),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (session.status == SessionStatus.waiting)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.video_call, size: 18),
                    label: const Text("Start"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => _openSession(session),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSession(SessionModel session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessionScreen(isCustomer: false, session: session),
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

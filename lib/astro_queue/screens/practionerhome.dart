import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/api_service.dart';
import 'package:flutter_learning/astro_queue/model/usermodel.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';
import 'package:flutter_learning/astro_queue/screens/practioner_queue_screen.dart';
import 'package:flutter_learning/astro_queue/screens/sessionscreen.dart';
import 'package:flutter_learning/astro_queue/services/websocketservice.dart';

class PractitionerHome extends StatefulWidget {
  const PractitionerHome({super.key});

  @override
  State<PractitionerHome> createState() => _PractitionerHomeState();
}

class _PractitionerHomeState extends State<PractitionerHome> {
  bool isLoading = false;
  String? errorMessage;
  int consultantId = 0;
  int queueCount = 0;
  ConsultationSessionResponse? currentSession;
  UserModel? currentUser;
  late WebSocketService webSocketService;

  @override
  void initState() {
    super.initState();
    webSocketService = WebSocketService();
    _loadPractitionerOnly();
  }

  Future<void> _loadPractitionerOnly() async {
    try {
      final user = await ApiService.getLoggedInUser();

      if (user != null && user.roleEnum.name.toLowerCase() == 'practitioner') {
        setState(() {
          consultantId = user.userId!;
          currentUser = user;
        });
        print("✅ PRACTITIONER CONFIRMED – ID: $consultantId");

        _connectWebSocket();
        _loadQueueDataSilently();
      } else {
        print("❌ Role: '${user?.roleEnum.name}'");
        setState(() {
          errorMessage = "Practitioner access only";
        });
      }
    } catch (e) {
      setState(() => errorMessage = "Session error: $e");
      print("Login error: $e");
    }
  }

  void _connectWebSocket() {
    if (consultantId == 0) return;

    webSocketService.connect(
      userId: consultantId,
      onSessionUpdate: (data) {
        print("Session update received: $data");
        _refreshData();
      },
      onQueueUpdate: (data) {
        print("Queue updated LIVE: $data");
        final newQueueSize = data['queueSize'] as int? ?? 0;

        if (newQueueSize != queueCount && mounted) {
          final oldCount = queueCount;
          setState(() {
            queueCount = newQueueSize;
          });

          if (newQueueSize > oldCount) {
            _showNewBookingPopup(newQueueSize);
          }
        }
      },
      onError: (error) {
        print("WebSocket error: $error");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("WebSocket connection issue: $error"),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
    );
  }

  void _showNewBookingPopup(int newQueueSize) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: Row(
          children: const [
            Icon(Icons.notifications_active, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text("New Booking!", style: TextStyle(color: Colors.orange)),
          ],
        ),
        content: Text(
          "A new customer has just booked a consultation.\n\n"
          "Current queue size: **$newQueueSize**",
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openQueue();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text("Open Queue"),
          ),
        ],
      ),
    );
  }

  Future<void> _loadQueueDataSilently() async {
    if (consultantId == 0) return;
    try {
      print("🔄 Loading queue & session for consultant $consultantId");

      final queue =
          await ApiService.getPractionerQueue(consultantId.toString());
      final session =
          await ApiService.getCurrentSession(consultantId.toString());

      if (mounted) {
        setState(() {
          queueCount = queue.length;
          currentSession = session;
          print(
              "Queue: $queueCount | Session: ${session != null ? 'Active' : 'None'}");

          if (session != null) {
            print(
                "Active session details: ID=${session.sessionId}, status=${session.status?.name ?? 'unknown'}");
          } else {
            print("No active/called session returned from backend");
          }
        });
      }
    } catch (e) {
      print("Queue/session load error: $e");
    }
  }

  Future<void> _refreshData() async {
    if (consultantId == 0 || !mounted) return;
    setState(() => isLoading = true);
    await _loadQueueDataSilently();
    if (mounted) setState(() => isLoading = false);
  }

  @override
  void dispose() {
    webSocketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasActiveCall = currentSession != null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          "👨‍⚕️ ${currentUser?.name ?? 'Practitioner Dashboard'}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: consultantId == 0 ? null : _refreshData,
          ),
        ],
      ),
      body: errorMessage != null
          ? _buildErrorScreen()
          : isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.green))
              : consultantId == 0
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.green),
                          SizedBox(height: 16),
                          Text("Checking practitioner login...",
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey)),
                        ],
                      ),
                    )
                  : _buildDashboard(),
      floatingActionButton: consultantId == 0
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openQueue(),
              backgroundColor: Colors.green.shade600,
              icon: const Icon(Icons.queue_play_next),
              label: const Text("📋 Queue"),
            ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, size: 100, color: Colors.red.shade400),
            const SizedBox(height: 24),
            Text(
              "Access Denied",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadPractitionerOnly,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/login'),
              icon: const Icon(Icons.logout),
              label: const Text("Logout"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final bool hasActiveCall = currentSession != null;

    return Column(
      children: [
        // Stats Cards
        Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  "📋 Waiting Queue",
                  "$queueCount",
                  Colors.orange,
                  () => _openQueue(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  "🎥 Active Call",
                  hasActiveCall ? "1" : "0",
                  hasActiveCall ? Colors.green : Colors.grey,
                  hasActiveCall ? () => _joinCurrentSession() : null,
                ),
              ),
            ],
          ),
        ),

        // Quick Actions
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openQueue(),
                  icon: const Icon(Icons.queue_play_next, color: Colors.white),
                  label: const Text("📋 Open Queue",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (hasActiveCall) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _joinCurrentSession(),
                    icon: const Icon(Icons.videocam, color: Colors.white),
                    label: const Text("📞 Join Call",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Welcome Card
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade50, Colors.green.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.green.shade200!, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 25,
                offset: const Offset(0, 12),
              )
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade400,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.support_agent,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Welcome Practitioner ${currentUser?.name ?? ''}",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "Ready to serve ${queueCount > 0 ? '$queueCount waiting customer${queueCount > 1 ? 's' : ''}' : 'your customers'}",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "👆 Tap 'Open Queue' to start consultations",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.green.shade600,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 25,
              offset: const Offset(0, 12),
            )
          ],
          border: Border.all(color: color.withOpacity(0.5), width: 2),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openQueue() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PractitionerQueueScreen(consultantId: consultantId),
      ),
    ).then((_) => _refreshData());
  }

  void _joinCurrentSession() async {
    if (currentSession == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No active session to join")),
      );
      return;
    }

    try {
      print("Joining session ID: ${currentSession!.sessionId}");

      final joinData = await ApiService.joinSession(
        sessionId: currentSession!.sessionId!,
        userId: consultantId,
        context: context,
      );

      if (joinData == null || !mounted) return;

      print("Join success - Channel: ${joinData["channelName"]}");

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SessionScreen(
            session: currentSession!,
            joinData: joinData, // ✅ PASS JOIN DATA HERE
          ),
        ),
      ).then((_) => _refreshData());
    } catch (e) {
      print("Join call failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to join call: $e"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }
}

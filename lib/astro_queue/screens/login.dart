import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/api_service.dart';
import 'package:flutter_learning/astro_queue/model/usermodel.dart';
import 'package:flutter_learning/router/approutes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController =
      TextEditingController(text: "chandu@gmail.com");
  final TextEditingController passwordController =
      TextEditingController(text: "12345678");
  final ApiService apiService = ApiService();

  bool obscurePassword = true;
  bool isLoading = false;
  String? errorMessage;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Replace _handleLogin() method:
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await apiService.login(
        emailController.text.trim(),
        passwordController.text,
      );

      // ✅ Parse successful response
      final Map<String, dynamic> userData = {
        "userId": response['userId'],
        "name": response['name'],
        "role": response['role'], // Keep original casing: "Practioner"
        "message": response['message']
      };

      // ✅ Store user
      await ApiService.storeUser(UserModel.fromLoginJson(userData));

      if (mounted) {
        final userRole = response['role'].toString().toLowerCase().trim();

        print("🔍 Detected role: '$userRole'"); // Debug log

        // ✅ FIXED: Proper role matching (case-insensitive)
        switch (userRole) {
          case 'customer':
            Navigator.pushReplacementNamed(context, AppRoutes.customerHome);
            break;
          case 'practitioner': // ✅ Matches "Practioner" → "practitioner"
          case 'practioner': // ✅ Covers typos/misspellings
            Navigator.pushReplacementNamed(context, AppRoutes.practitionerHome);
            break;
          default:
            // ✅ SHOW WARNING instead of generic home
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text("Unknown role: ${response['role']}. Contact support."),
                backgroundColor: Colors.orange,
                action: SnackBarAction(
                  label: 'Go Home',
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, AppRoutes.home),
                ),
              ),
            );
            break;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff6A11CB), Color(0xff2575FC)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            // ✅ Keyboard-safe padding
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 40,
            ),
            child: Column(
              children: [
                // Header - Fixed size
                const SizedBox(
                  height: 120,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Astro Talk",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Login to manage your queue",
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                ),

                // Login Card - Compact responsive
                Container(
                  constraints:
                      const BoxConstraints(maxWidth: 400), // Responsive
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Welcome Back",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff2575FC),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Enter your credentials",
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 24),

                        // Email Field
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: InputDecoration(
                            labelText: "Email",
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide:
                                  const BorderSide(color: Color(0xff2575FC)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Email required';
                            if (!value.contains('@'))
                              return 'Valid email required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        TextFormField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: InputDecoration(
                            labelText: "Password",
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () => setState(
                                  () => obscurePassword = !obscurePassword),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide:
                                  const BorderSide(color: Color(0xff2575FC)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Password required';
                            if (value.length < 6) return 'Min 6 characters';
                            return null;
                          },
                        ),

                        // Error Message (compact)
                        if (errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error,
                                    size: 18, color: Colors.red.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(errorMessage!,
                                        style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontSize: 13))),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () =>
                                ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Coming soon!"),
                                  duration: Duration(seconds: 2)),
                            ),
                            child: const Text("Forgot Password?",
                                style: TextStyle(color: Color(0xff2575FC))),
                          ),
                        ),

                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff2575FC),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: isLoading ? null : _handleLogin,
                            child: isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text("Login",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40), // Bottom spacing
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_learning/product/login/model/customer_login_model.dart';
import 'package:flutter_learning/product/login/model/login_request.dart';
import 'package:flutter_learning/product/login/screens/otp_screen.dart';
import 'package:flutter_learning/product/login/service/login_service.dart';
import 'package:http/http.dart' as http;

class ShopifyLogin extends StatefulWidget {
  const ShopifyLogin({super.key});

  @override
  State<ShopifyLogin> createState() => _ShopifyLoginState();
}

class _ShopifyLoginState extends State<ShopifyLogin> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController =
      TextEditingController(text: "chandrakala");
  final TextEditingController _lastNameController =
      TextEditingController(text: "Golla");
  final TextEditingController _emailController =
      TextEditingController(text: "chandrakala@neoterictechnologiesinc.com");
  final TextEditingController _phoneController =
      TextEditingController(text: "9908235913");

  bool _isLoading = false;
  bool _isLoginMode = false; // ✅ Toggle for email-only mode
  String _buttonText = "Create Account";
  String _titleText = "Create Account";
  String _subtitleText = "Enter your details to get started";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // ✅ Logo
                Image.asset(
                  'assets/images/shopify.png',
                  height: 80,
                  width: 100,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),

                // ✅ Dynamic Title
                Text(
                  _titleText,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _subtitleText,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // ✅ Conditional Form Fields
                if (!_isLoginMode) ...[
                  // ✅ SIGNUP MODE - All fields
                  TextFormField(
                    controller: _firstNameController,
                    decoration:
                        _inputDecoration("First Name", Icons.person_outline),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty)
                        return "Enter first name";
                      if (value.trim().length < 2) return "Name too short";
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _lastNameController,
                    decoration:
                        _inputDecoration("Last Name", Icons.person_outline),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty)
                        return "Enter last name";
                      if (value.trim().length < 2) return "Name too short";
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // ✅ EMAIL FIELD (Always visible)
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  readOnly: _isLoginMode, // ✅ Read-only in login mode
                  decoration: _inputDecoration("Email", Icons.email_outlined),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return "Enter your email";
                    if (!_isValidEmail(value)) return "Enter valid email";
                    return null;
                  },
                ),

                if (!_isLoginMode) ...[
                  const SizedBox(height: 16),

                  // ✅ PHONE FIELD (Signup only)
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecoration("Phone", Icons.phone_outlined),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return "Enter phone number";
                      if (!_isValidPhone(value)) return "Enter valid phone";
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 32),

                // ✅ Dynamic Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _buttonText,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // ✅ Toggle Link
                GestureDetector(
                  onTap: _toggleMode,
                  child: Text(
                    _isLoginMode
                        ? "Need new account? Create Account"
                        : "Already have account? Login",
                    style: TextStyle(
                      color: Colors.orange.shade600,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey[600]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.orange.shade400, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isValidPhone(String phone) {
    return RegExp(r'^\+?[\d\s-]{10,}$')
        .hasMatch(phone.replaceAll(RegExp(r'[^\d+]'), ''));
  }

  // ✅ Toggle between signup/login mode
  void _toggleMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
      _firstNameController.clear();
      _lastNameController.clear();
      _phoneController.clear();

      if (_isLoginMode) {
        _titleText = "Welcome Back";
        _subtitleText = "Enter your email to login";
        _buttonText = "Send OTP";
      } else {
        _titleText = "Create Account";
        _subtitleText = "Enter your details to get started";
        _buttonText = "Create Account";
        // Restore test data
        _firstNameController.text = "chandrakala";
        _lastNameController.text = "Golla";
        _phoneController.text = "9908235913";
      }
    });
  }

  // ✅ Unified submit handler
  // ✅ UPDATE _handleSubmit() method ONLY:
  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        bool isLoginFlow = _isLoginMode; // ✅ Flag for OTP screen

        if (_isLoginMode) {
          final request = LoginRequest(
            email: _emailController.text.trim(),
          );
          await LoginService().customerLogin(request);
          _showSuccessSnackBar("OTP sent to your email!");

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPScreen(
                phoneNumber: _emailController.text,
                email: _emailController.text,
                isLoginFlow: isLoginFlow, // ✅ PASS FLAG
              ),
            ),
          );
        } else {
          final request = CustomerLoginModel(
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
          );
          await LoginService().customerSignUp(request);
          _showSuccessSnackBar("Account created! OTP sent.");

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPScreen(
                phoneNumber: _phoneController.text,
                email: _emailController.text,
                isLoginFlow: isLoginFlow, // ✅ PASS FLAG
              ),
            ),
          );
        }
      } catch (e) {
        if (e.toString().toLowerCase().contains('already exists') ||
            e.toString().toLowerCase().contains('exist')) {
          _switchToLoginMode();
        } else {
          _showErrorSnackBar(
              e.toString().replaceFirst('Exception: Failed: ', ''));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _switchToLoginMode() {
    setState(() {
      _isLoginMode = true;
      _firstNameController.clear();
      _lastNameController.clear();
      _phoneController.clear();
      _titleText = "Welcome Back";
      _subtitleText = "Enter your email to login";
      _buttonText = "Send OTP";
    });

    _showInfoSnackBar("Account exists! Enter email to login.");
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}

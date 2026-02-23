import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_learning/product/login/model/customer_login_model.dart';
import 'package:flutter_learning/product/login/model/login_request.dart';
import 'package:flutter_learning/product/login/screens/otp_screen.dart';
import 'package:flutter_learning/product/login/service/login_service.dart';

class ShopifyLogin extends StatefulWidget {
  const ShopifyLogin({super.key});

  @override
  State<ShopifyLogin> createState() => _ShopifyLoginState();
}

class _ShopifyLoginState extends State<ShopifyLogin> {
  final _formKey = GlobalKey<FormState>();
  final _messengerKey =
      GlobalKey<ScaffoldMessengerState>(); // ← This fixes SnackBar issues

  final TextEditingController _firstNameController =
      TextEditingController(text: "chandrakala");
  final TextEditingController _lastNameController =
      TextEditingController(text: "Golla");
  final TextEditingController _emailController =
      TextEditingController(text: "chandrakala@neoterictechnologiesinc.com");
  final TextEditingController _phoneController =
      TextEditingController(text: "9908235913");

  bool _isLoading = false;
  bool _isLoginMode = false;

  String _buttonText = "Create Account";
  String _titleText = "Create Account";
  String _subtitleText = "Enter your details to get started";

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),
                  Image.asset(
                    'assets/images/shopify.png',
                    height: 80,
                    width: 100,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 32),
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
                  const SizedBox(height: 40),
                  if (!_isLoginMode) ...[
                    TextFormField(
                      controller: _firstNameController,
                      decoration:
                          _inputDecoration("First Name", Icons.person_outline),
                      textCapitalization: TextCapitalization.words,
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
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty)
                          return "Enter last name";
                        if (value.trim().length < 2) return "Name too short";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    readOnly: _isLoginMode,
                    decoration: _inputDecoration("Email", Icons.email_outlined),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty)
                        return "Enter your email";
                      if (!_isValidEmail(value.trim()))
                        return "Enter valid email";
                      return null;
                    },
                  ),
                  if (!_isLoginMode) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration:
                          _inputDecoration("Phone", Icons.phone_outlined),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty)
                          return "Enter phone number";
                        if (!_isValidPhone(value.trim()))
                          return "Enter valid phone";
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 40),
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
                                strokeWidth: 2.5,
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
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _toggleMode,
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(color: Colors.grey[700], fontSize: 16),
                        children: [
                          TextSpan(
                            text: _isLoginMode
                                ? "Don't have an account? "
                                : "Already have an account? ",
                          ),
                          TextSpan(
                            text: _isLoginMode ? "Create Account" : "Login",
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
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
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.orange.shade400, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isValidPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    return RegExp(r'^\+?[0-9]{10,15}$').hasMatch(cleaned);
  }

  void _toggleMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;

      if (_isLoginMode) {
        _titleText = "Welcome Back";
        _subtitleText = "Enter your email to continue";
        _buttonText = "Send OTP";
        _firstNameController.clear();
        _lastNameController.clear();
        _phoneController.clear();
      } else {
        _titleText = "Create Account";
        _subtitleText = "Enter your details to get started";
        _buttonText = "Create Account";
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final isLoginFlow = _isLoginMode;

      if (_isLoginMode) {
        final request = LoginRequest(email: _emailController.text.trim());
        await LoginService().customerLogin(request);

        _showSnackBar("OTP sent to your email!", isSuccess: true);

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPScreen(
              // ← use context here (the one from build)
              phoneNumber: "",
              email: _emailController.text.trim(),
              isLoginFlow: isLoginFlow,
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

        _showSnackBar("Account created! OTP sent.", isSuccess: true);

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPScreen(
              phoneNumber: _phoneController.text.trim(),
              email: _emailController.text.trim(),
              isLoginFlow: isLoginFlow,
            ),
          ),
        );
      }
    } catch (e) {
      String message = e.toString().replaceAll('Exception: ', '').trim();

      if (message.toLowerCase().contains('already exists') ||
          message.toLowerCase().contains('exist')) {
        _switchToLoginMode();
      } else {
        _showSnackBar(
          message.isEmpty ? "Something went wrong" : message,
          isSuccess: false,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _switchToLoginMode() {
    setState(() {
      _isLoginMode = true;
      _titleText = "Welcome Back";
      _subtitleText = "Enter your email to continue";
      _buttonText = "Send OTP";
      _firstNameController.clear();
      _lastNameController.clear();
      _phoneController.clear();
    });
    _showSnackBar("Account already exists. Please login.",
        isSuccess: false, isInfo: true);
  }

  void _showSnackBar(String message,
      {bool isSuccess = false, bool isInfo = false}) {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return; // safety check

    final color = isSuccess
        ? Colors.green.shade700
        : isInfo
            ? Colors.orange.shade700
            : Colors.red.shade700;

    final icon = isSuccess
        ? Icons.check_circle
        : isInfo
            ? Icons.info
            : Icons.error_outline;

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          duration: const Duration(seconds: 4),
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

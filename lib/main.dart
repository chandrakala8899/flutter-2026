import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/screens/login.dart';
import 'package:flutter_learning/router/app_router.dart';
import 'package:flutter_learning/router/approutes.dart';

void main() {
  runApp(const AstrologyQueueApp());
}

class AstrologyQueueApp extends StatelessWidget {
  const AstrologyQueueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Consultation App',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      // home: const LoginScreen(),
      //  home: const ShopifyLogin(),
      initialRoute: AppRoutes.login,
      onGenerateRoute: AppRouter.generateRoute,

      // ✅ Named routes for convenience
      routes: {
        AppRoutes.login: (context) => const LoginScreen(),
      },
    );
  }
}

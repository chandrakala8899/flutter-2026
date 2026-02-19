import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/screens/customerhome.dart';
import 'package:flutter_learning/astro_queue/screens/login.dart';
import 'package:flutter_learning/astro_queue/screens/practionerhome.dart';
import 'package:flutter_learning/router/approutes.dart';

class AppRouter {
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      // Auth Routes
      case AppRoutes.login:
        return _pageRoute(() => const LoginScreen());
      case AppRoutes.home:
        return _pageRoute(() => const Scaffold(body: Center(child: Text('Home'))));

      // Customer Routes  
      case AppRoutes.customerHome:
        return _pageRoute(() =>  CustomerHome());

      // Practitioner Routes
      case AppRoutes.practitionerHome:
        return _pageRoute(() =>  PractitionerHome());

      default:
        return _errorRoute(settings.name!);
    }
  }

  static PageRouteBuilder<dynamic> _pageRoute(Widget Function() page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  static Route<dynamic> _errorRoute(String routeName) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        body: Center(
          child: Text('No route found: $routeName'),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_learning/product/login/screens/shopify_login.dart';

void main() {
  runApp(const AstrologyQueueApp());
}

class AstrologyQueueApp extends StatelessWidget {
  const AstrologyQueueApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MultiProvider(
//       providers: [
//         ChangeNotifierProvider(create: (_) => QueueProvider()),
//       ],
//       child: const MaterialApp(
//         debugShowCheckedModeBanner: false,
//         home: AstroHomeScreen(),
//       ),
//     );
//   }
// }

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
      home: const ShopifyLogin(),
      // initialRoute: AppRoutes.login,
      // onGenerateRoute: AppRouter.generateRoute,

      // // ✅ Named routes for convenience
      // routes: {
      //   AppRoutes.login: (context) => const LoginScreen(),
      // },
    );
  }
}

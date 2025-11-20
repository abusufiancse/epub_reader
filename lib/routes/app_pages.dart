// routes/app_pages.dart
import 'package:get/get.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart'; // Add this import
import '../screens/splash_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register'; // Add this
  static const String home = '/home';
}

class AppPages {
  static final List<GetPage> routes = [
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashScreen(),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => LoginScreen(),
    ),
    GetPage(
      name: AppRoutes.register, // Add this
      page: () => RegisterScreen(),
    ),
    GetPage(
      name: AppRoutes.home,
      page: () =>  HomeScreen(),
    ),
  ];
}
// routes/app_pages.dart
import 'package:get/get.dart';
import '../models/book_model.dart';
import '../screens/book_detail_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/splash_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String bookDetail = '/book-detail';
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
      name: AppRoutes.register,
      page: () => RegisterScreen(),
    ),
    GetPage(
      name: AppRoutes.home,
      page: () =>  HomeScreen(),
    ),
    GetPage(
      name: AppRoutes.bookDetail, // Add this
      page: () {
        final BookModel book = Get.arguments;
        return BookDetailScreen(book: book);
      },
    ),
  ];
}
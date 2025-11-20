// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'controllers/auth_controller.dart';
import 'controllers/book_controller.dart';
import 'core/themes/app_theme.dart';
import 'routes/app_pages.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dependencies
  await initializeDependencies();

  runApp(const MyApp());
}

Future<void> initializeDependencies() async {
  // Initialize GetStorage
  await GetStorage.init();

  // Initialize SharedPreferences
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  Get.put<SharedPreferences>(prefs, permanent: true);

  // Initialize AuthController
  Get.put<AuthController>(AuthController(), permanent: true);

  // Initialize BookController
  Get.put<BookController>(BookController(), permanent: true);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) {
        return GetMaterialApp(
          title: 'EPUB Reader',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          initialRoute: AppRoutes.splash,
          getPages: AppPages.routes,
          debugShowCheckedModeBanner: false,
          // Prevent duplicate controllers
          smartManagement: SmartManagement.onlyBuilder,
        );
      },
    );
  }
}
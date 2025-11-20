// controllers/auth_controller.dart
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:logger/logger.dart';

import '../core/constants/app_constants.dart';
import '../models/user_model.dart';
import '../routes/app_pages.dart';
import '../utils/network_caller.dart';

class AuthController extends GetxController {
  final RxBool isLoading = false.obs;
  final RxBool isLoggedIn = false.obs;
  final Rx<UserModel?> user = Rx<UserModel?>(null);

  final GetStorage _storage = GetStorage();
  final NetworkCaller _networkCaller = NetworkCaller();
  final Logger _logger = Logger();

  @override
  void onInit() {
    super.onInit();
    _checkAuthenticationStatus();
  }

  void _checkAuthenticationStatus() {
    final token = _storage.read('token');
    final userData = _storage.read('user');

    if (token != null && userData != null) {
      try {
        user.value = UserModel.fromJson(userData);
        isLoggedIn.value = true;
        _logger.i('User authenticated: ${user.value?.email}');
      } catch (e) {
        _logger.e('Error restoring user data: $e');
        _clearAuthData();
      }
    }
  }

  Future<bool> login(String login, String password) async {
    try {
      isLoading.value = true;

      final response = await _networkCaller.postRequest(
        url: '${AppConstants.baseUrl}login',
        body: {
          'login': login,
          'password': password,
        },
        includeToken: false,
      );

      if (response.isSuccess && response.responseData['success'] == true) {
        await _storeAuthData(response.responseData);
        _logger.i('Login successful for: $login');
        return true;
      } else {
        _logger.e('Login failed: ${response.errorMess}');
        // Don't show error to user, just log it
        return false;
      }
    } catch (e) {
      _logger.e('Login exception: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _storeAuthData(Map<String, dynamic> responseData) async {
    await _storage.write('token', responseData['token']);
    await _storage.write('user', responseData['user']);

    user.value = UserModel.fromJson(responseData['user']);
    isLoggedIn.value = true;
  }

  Future<void> logout() async {
    _logger.i('User logout: ${user.value?.email}');
    _clearAuthData();
    Get.offAllNamed(AppRoutes.login);
  }

  void _clearAuthData() {
    _storage.remove('token');
    _storage.remove('user');
    user.value = null;
    isLoggedIn.value = false;
  }

  String? get token => _storage.read('token');
}
// controllers/auth_controller.dart
import 'package:flutter/material.dart';
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
        url: '${AppConstants.baseUrl}${AppConstants.loginEndpoint}',
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
        return false;
      }
    } catch (e) {
      _logger.e('Login exception: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Add register method
  // In the register method of auth_controller.dart
  Future<bool> register(String name, String email, String phone, String password, String passwordConfirmation) async {
    try {
      isLoading.value = true;

      final response = await _networkCaller.postRequest(
        url: '${AppConstants.baseUrl}${AppConstants.registerEndpoint}',
        body: {
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
        includeToken: false,
      );

      if (response.isSuccess && response.responseData['success'] == true) {
        await _storeAuthData(response.responseData);
        _logger.i('Registration successful for: $email');
        return true;
      } else {
        // Extract error message from backend response
        String errorMessage = 'Registration failed';
        if (response.responseData != null) {
          errorMessage = response.responseData['error'] ??
              response.responseData['message'] ??
              response.errorMess;
        }

        _logger.e('Registration failed: $errorMessage');

        // Show user-friendly error message
        Get.rawSnackbar(
          message: errorMessage,
          backgroundColor: Colors.red,
          borderRadius: 8,
          margin: const EdgeInsets.all(16),
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );

        return false;
      }
    } catch (e) {
      _logger.e('Registration exception: $e');

      Get.rawSnackbar(
        message: 'Network error. Please try again.',
        backgroundColor: Colors.red,
        borderRadius: 8,
        margin: const EdgeInsets.all(16),
        snackPosition: SnackPosition.BOTTOM,
      );

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
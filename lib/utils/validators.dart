// utils/validators.dart
class Validators {
  static String? validateLogin(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email or phone number';
    }

    // Check if it's a phone number (11 digits Bangladesh format)
    if (RegExp(r'^01[3-9]\d{8}$').hasMatch(value)) {
      return null;
    }

    // Check if it's a valid email
    if (RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return null;
    }

    return 'Please enter a valid phone number (01XXXXXXXXX) or email address';
  }

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email address';
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }

    if (!RegExp(r'^01[3-9]\d{8}$').hasMatch(value)) {
      return 'Please enter a valid Bangladeshi phone number (01XXXXXXXXX)';
    }

    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 8) { // Changed from 6 to 8
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  // Helper method to check if input is phone or email
  static bool isPhone(String input) {
    return RegExp(r'^01[3-9]\d{8}$').hasMatch(input);
  }

  static bool isEmail(String input) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(input);
  }
}
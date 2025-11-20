// screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../core/constants/app_colors.dart';
import '../routes/app_pages.dart';
import '../utils/validators.dart';
import '../widgets/custom_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _rememberMe = false;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      final success = await _authController.login(
        _loginController.text.trim(),
        _passwordController.text.trim(),
      );

      if (success) {
        _showSuccessSnackbar();
        Get.offAllNamed(AppRoutes.home);
      } else {
        _showErrorSnackbar();
      }
    }
  }

  void _showSuccessSnackbar() {
    Get.rawSnackbar(
      message: 'Login successful!',
      backgroundColor: Colors.green,
      borderRadius: 8,
      margin: const EdgeInsets.all(16),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _showErrorSnackbar() {
    Get.rawSnackbar(
      message: 'Invalid credentials',
      backgroundColor: Colors.red,
      borderRadius: 8,
      margin: const EdgeInsets.all(16),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  // Dynamic label and icon based on input
  String get _loginFieldLabel {
    final text = _loginController.text.trim();
    if (text.isEmpty) return 'Email or Phone Number';
    if (Validators.isPhone(text)) return 'Phone Number';
    if (Validators.isEmail(text)) return 'Email Address';
    return 'Email or Phone Number';
  }

  IconData get _loginFieldIcon {
    final text = _loginController.text.trim();
    if (text.isEmpty) return Icons.person_outline;
    if (Validators.isPhone(text)) return Icons.phone_outlined;
    return Icons.email_outlined;
  }

  TextInputType get _keyboardType {
    final text = _loginController.text.trim();
    if (Validators.isPhone(text)) return TextInputType.phone;
    return TextInputType.emailAddress;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),

              // Back Button
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_ios, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),

              const SizedBox(height: 40),

              // Title
              Text(
                'Sign in to EPUB Reader',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Welcome back! Please enter your details.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 40),

              // Login Form
              _buildLoginForm(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Dynamic Login Field (Email/Phone)
          StatefulBuilder(
            builder: (context, setState) {
              return CustomTextField(
                label: _loginFieldLabel,
                controller: _loginController,
                validator: Validators.validateLogin,
                keyboardType: _keyboardType,
                prefixIcon: _loginFieldIcon,
                onChanged: (value) => setState(() {}),
              );
            },
          ),

          const SizedBox(height: 20),

          // Password Field
          CustomTextField(
            label: 'Password',
            controller: _passwordController,
            validator: Validators.validatePassword,
            obscureText: _obscurePassword,
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey.shade500,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),

          const SizedBox(height: 16),

          // Remember Me & Forgot Password
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Remember Me
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (value) => setState(() => _rememberMe = value ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  Text(
                    'Remember me',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),

              // Forgot Password
              TextButton(
                onPressed: () {
                  Get.rawSnackbar(
                    message: 'Password reset feature coming soon',
                    backgroundColor: AppColors.primary,
                    borderRadius: 8,
                    margin: const EdgeInsets.all(16),
                  );
                },
                child: Text(
                  'Forgot Password?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Sign In Button
          Obx(() => SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _authController.isLoading.value ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _authController.isLoading.value
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Text(
                'Sign In',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )),

          const SizedBox(height: 32),

          // Sign Up Section
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an account?",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Get.rawSnackbar(
                    message: 'Sign up feature coming soon',
                    backgroundColor: AppColors.primary,
                    borderRadius: 8,
                    margin: const EdgeInsets.all(16),
                  );
                },
                child: Text(
                  'Sign Up',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
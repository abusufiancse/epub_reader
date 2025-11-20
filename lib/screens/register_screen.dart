// screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../core/constants/app_colors.dart';
import '../routes/app_pages.dart';
import '../utils/validators.dart';
import '../widgets/custom_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      final success = await _authController.register(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _phoneController.text.trim(),
        _passwordController.text.trim(),
        _confirmPasswordController.text.trim(),
      );

      if (success) {
        _showSuccessSnackbar();
        Get.offAllNamed(AppRoutes.home);
      }
      // Error handling is now done in the controller with proper messages
    }
  }

  void _showSuccessSnackbar() {
    Get.rawSnackbar(
      message: 'Registration successful!',
      backgroundColor: Colors.green,
      borderRadius: 8,
      margin: const EdgeInsets.all(16),
      snackPosition: SnackPosition.BOTTOM,
    );
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
                'Create Account',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Join us and start your reading journey',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 40),

              // Registration Form
              _buildRegisterForm(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Name Field
          CustomTextField(
            label: 'Full Name',
            controller: _nameController,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your full name';
              }
              if (value.length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
            keyboardType: TextInputType.name,
            prefixIcon: Icons.person_outline,
          ),

          const SizedBox(height: 20),

          // Email Field
          CustomTextField(
            label: 'Email Address',
            controller: _emailController,
            validator: Validators.validateEmail,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
          ),

          const SizedBox(height: 20),

          // Phone Field
          CustomTextField(
            label: 'Phone Number',
            controller: _phoneController,
            validator: Validators.validatePhone,
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_outlined,
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

          const SizedBox(height: 20),

          // Confirm Password Field
          CustomTextField(
            label: 'Confirm Password',
            controller: _confirmPasswordController,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
            obscureText: _obscureConfirmPassword,
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey.shade500,
              ),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),

          const SizedBox(height: 8),

          // Password hint
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Password must be at least 8 characters long',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Register Button
          Obx(() => SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _authController.isLoading.value ? null : _register,
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
                'Create Account',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )),

          const SizedBox(height: 32),

          // Login Section
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Already have an account?",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Get.offAllNamed(AppRoutes.login),
                child: Text(
                  'Sign In',
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
// lib/screens/change_password_screen.dart

import 'package:flutter/material.dart';
import '../colors/app_color.dart';
import '../services/api_services.dart';
import 'navbar_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _oldPwdController = TextEditingController();
  final TextEditingController _newPwdController = TextEditingController();
  final TextEditingController _confirmPwdController = TextEditingController();

  bool _isLoading = false;
  bool _oldObscured = true;
  bool _newObscured = true;
  bool _confirmObscured = true;

  @override
  void dispose() {
    _oldPwdController.dispose();
    _newPwdController.dispose();
    _confirmPwdController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPwdController.text != _confirmPwdController.text) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New and confirm passwords do not match.'), backgroundColor: AppColors.kErrorRed),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final message = await apiService.changePassword(
        _newPwdController.text,
        _confirmPwdController.text,
        _oldPwdController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.kSuccessGreen),
      );

      // Clear fields on success
      _oldPwdController.clear();
      _newPwdController.clear();
      _confirmPwdController.clear();
    } on Exception catch (e) {
      if (!mounted) return;
      String errorMessage = e.toString();
      if (errorMessage.contains('404')) {
        errorMessage = 'Password change service temporarily unavailable. Try again later.';
      } else if (errorMessage.contains('Failed host lookup')) {
        errorMessage = 'No internet connection. Please check your network.';
      } else if (errorMessage.contains('timeout')) {
        errorMessage = 'Server took too long to respond. Try again later.';
      } else {
        errorMessage = errorMessage.replaceFirst('Exception: ', '');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: AppColors.kErrorRed),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPasswordField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool obscured,
    required VoidCallback toggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscured,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            if (controller == _newPwdController && v.length < 6) return 'Use at least 6 characters';
            return null;
          },
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 10, right: 6),
              child: Icon(Icons.lock_outline, size: 20, color: Colors.grey),
            ),
            suffixIcon: IconButton(
              icon: Icon(obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey),
              onPressed: toggle,
              tooltip: obscured ? 'Show password' : 'Hide password',
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: AppColors.kDarkBlue, width: 1.8),
            ),
            hintStyle: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // We wrap in SafeArea and center card width to look like a panel in the screenshot
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFE9F0FF),
        appBar: AppBar(
          elevation: 0, // remove default shadow
          title: Text(
            'Change Password',
            style: TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          centerTitle: true,
          backgroundColor: AppColors.appbarblue,
          foregroundColor: Colors.white,
        ),
      
        drawer: NavbarScreen(),
        body: SafeArea(
      child: LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight, // ✅ enables vertical centering
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 520, // card width
                  ),
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    color: AppColors.kWhite,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 22),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min, // 🔑 important
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPasswordField(
                              label: 'Current Password',
                              hint: 'Enter your current password',
                              controller: _oldPwdController,
                              obscured: _oldObscured,
                              toggle: () =>
                                  setState(() => _oldObscured = !_oldObscured),
                            ),
      
                            const SizedBox(height: 16),
      
                            _buildPasswordField(
                              label: 'New Password',
                              hint: 'Enter a strong new password',
                              controller: _newPwdController,
                              obscured: _newObscured,
                              toggle: () =>
                                  setState(() => _newObscured = !_newObscured),
                            ),
      
                            const SizedBox(height: 10),
      
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: FractionallySizedBox(
                                widthFactor: 0.35,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.kLightBlue,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ),
      
                            const SizedBox(height: 18),
      
                            _buildPasswordField(
                              label: 'Confirm New Password',
                              hint: 'Re-enter your new password',
                              controller: _confirmPwdController,
                              obscured: _confirmObscured,
                              toggle: () => setState(
                                      () => _confirmObscured = !_confirmObscured),
                            ),
      
                            const SizedBox(height: 18),
      
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed:
                                _isLoading ? null : _handleChangePassword,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.appbarblue,
                                  padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                    : const Text(
                                  'Update Password',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      ),
      ),
      
      ),
    );
  }
}

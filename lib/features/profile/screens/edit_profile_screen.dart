// lib/features/settings/screens/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart'; // Added for Clipboard

import '../../../core/network/api_service.dart';
import '../../../core/constants/endpoints.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  // Controllers for editable fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // Password controllers
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // User data from Hive
  Map<String, dynamic> _userData = {};
  bool _isSaving = false;
  bool _isChangingPassword = false;
  bool _isEditMode = true;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isUserLoggedIn = false;
  bool _hasInternetConnection = true;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _pageBackground =>
      _isDark ? const Color(0xFF09111F) : Colors.grey.shade50;
  Color get _surfaceColor => _isDark ? const Color(0xFF101A2B) : Colors.white;
  Color get _secondarySurfaceColor =>
      _isDark ? const Color(0xFF162235) : const Color(0xFFF8FAFC);
  Color get _titleColor => _isDark ? const Color(0xFFF8FAFC) : Colors.black87;
  Color get _bodyColor =>
      _isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade600;
  Color get _mutedColor =>
      _isDark ? const Color(0xFF94A3B8) : Colors.grey.shade400;
  Color get _borderColor =>
      _isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
    _checkInternetConnection();
  }

  Future<void> _checkAuthentication() async {
    try {
      final box = await Hive.openBox('user_box');
      final userData = box.get('current_user');

      if (userData != null && userData['id'] != null) {
        setState(() {
          _isUserLoggedIn = true;
          _userData = Map<String, dynamic>.from(userData);
          _nameController.text = _userData['name'] ?? '';
          _bioController.text = _userData['bio'] ?? '';
          _emailController.text = _userData['email'] ?? '';
          _phoneController.text = _userData['phone'] ?? '';
          _locationController.text = _userData['location'] ?? '';
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/signin');
        });
      }
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/signin');
      });
    }
  }

  Future<void> _checkInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      setState(() {
        _hasInternetConnection = connectivityResult != ConnectivityResult.none;
      });
    } catch (e) {
      setState(() {
        _hasInternetConnection = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_isUserLoggedIn) return;

    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      setState(() => _isSaving = true);

      try {
        final userId = _userData['id'];
        final email = _userData['email'];

        if (_hasInternetConnection) {
          await ApiService().updateProfile(
            userId: userId,
            email: email,
            name: _nameController.text,
            bio: _bioController.text,
            phone: _phoneController.text,
            location: _locationController.text,
          );
        }

        final box = await Hive.openBox('user_box');
        final updatedUserData = Map<String, dynamic>.from(_userData);
        updatedUserData['name'] = _nameController.text;
        updatedUserData['bio'] = _bioController.text;
        updatedUserData['phone'] = _phoneController.text;
        updatedUserData['location'] = _locationController.text;
        await box.put('current_user', updatedUserData);

        setState(() {
          _userData = updatedUserData;
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _hasInternetConnection
                  ? 'Profile updated successfully!'
                  : 'Profile saved offline. Sync when online.',
            ),
            backgroundColor: _hasInternetConnection
                ? Colors.green
                : Colors.orange,
            behavior: SnackBarBehavior.fixed,
            duration: const Duration(seconds: 3),
          ),
        );
      } catch (e) {
        setState(() => _isSaving = false);
        _showError(
          'Failed to save profile, check your internet connect or contact support (rbaacademy0@gmail.com)',
        );
      }
    }
  }

  Future<void> _changePassword() async {
    if (!_isUserLoggedIn) return;

    if (_passwordFormKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      setState(() => _isChangingPassword = true);

      try {
        final userId = _userData['id'];
        final email = _userData['email'];
        final newPassword = _newPasswordController.text;

        final bool hasPassword =
            _userData['has_password'] == true ||
            _userData['login_method'] == 'email';

        String? currentPassword = hasPassword
            ? _currentPasswordController.text
            : null;

        if (_hasInternetConnection) {
          await ApiService().updatePassword(
            userId: userId,
            email: email,
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
        }

        final box = await Hive.openBox('user_box');
        final currentUserData = box.get('current_user');
        if (currentUserData != null) {
          final updatedUserData = Map<String, dynamic>.from(currentUserData);
          updatedUserData['password'] = newPassword;
          updatedUserData['has_password'] = true;
          await box.put('current_user', updatedUserData);
        }

        setState(() => _isChangingPassword = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _hasInternetConnection
                  ? (hasPassword
                        ? 'Password changed successfully!'
                        : 'Password set successfully!')
                  : 'Password saved offline. Sync when online.',
            ),
            backgroundColor: _hasInternetConnection
                ? Colors.green
                : Colors.orange,
            behavior: SnackBarBehavior.fixed,
            duration: const Duration(seconds: 3),
          ),
        );

        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } catch (e) {
        setState(() => _isChangingPassword = false);
        _showError(
          'Failed to save password, check your internet connect or contact support (rbaacademy0@gmail.com)',
        );
      }
    }
  }

  // New method to copy text to clipboard
  Future<void> _copyToClipboard(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.fixed,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // New method to open WhatsApp
  Future<void> _openWhatsApp(String phone) async {
    final url = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _showError('Could not open WhatsApp');
    }
  }

  // New method to make a phone call
  Future<void> _makePhoneCall(String phone) async {
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      _showError('Could not make a call');
    }
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: _surfaceColor,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(
            20,
          ), // ADJUST THIS: Controls dialog margin from screen edges
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(
              20,
            ), // ADJUST THIS: Controls inner padding
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ADJUST THIS SECTION: Title row - fixed pixel alignment
                Row(
                  children: [
                    Icon(
                      Icons.help_outline,
                      color: Colors.blue.shade600,
                      size: 22,
                    ), // ADJUST: Icon size
                    const SizedBox(
                      width: 10,
                    ), // ADJUST: Space between icon and text
                    const Expanded(
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18, // ADJUST: Font size
                          height:
                              1.2, // ADJUST: Line height to fix pixel issues
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16), // ADJUST: Space below title

                Text(
                  'Please contact the management team to reset your password.',
                  style: TextStyle(fontSize: 14, color: _bodyColor),
                ),
                const SizedBox(
                  height: 20,
                ), // ADJUST: Space above contact options
                // WhatsApp Contact
                Container(
                  padding: const EdgeInsets.all(
                    12,
                  ), // ADJUST: Container padding
                  decoration: BoxDecoration(
                    color: _isDark
                        ? Colors.green.withOpacity(0.12)
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isDark
                          ? Colors.green.withOpacity(0.22)
                          : Colors.green.shade100,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_outlined,
                        color: Colors.green.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8), // ADJUST: Space after icon
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chat on WhatsApp',
                              style: TextStyle(
                                fontSize: 12,
                                color: _bodyColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(
                              height: 4,
                            ), // ADJUST: Space between label and number
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _openWhatsApp('2348169902281'),
                                    child: Text(
                                      '08169902281',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.green.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.content_copy,
                                    size: 16,
                                    color: Colors.green.shade600,
                                  ),
                                  onPressed: () => _copyToClipboard(
                                    '08169902281',
                                    'Phone number copied!',
                                  ),
                                  padding: EdgeInsets
                                      .zero, // ADJUST: Remove button padding
                                  constraints: const BoxConstraints(
                                    minWidth: 30,
                                  ), // ADJUST: Button size
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 12,
                ), // ADJUST: Space between contact options
                // Phone Call Contact
                Container(
                  padding: const EdgeInsets.all(
                    12,
                  ), // ADJUST: Container padding
                  decoration: BoxDecoration(
                    color: _isDark
                        ? Colors.blue.withOpacity(0.12)
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isDark
                          ? Colors.blue.withOpacity(0.22)
                          : Colors.blue.shade100,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8), // ADJUST: Space after icon
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Call Support',
                              style: TextStyle(
                                fontSize: 12,
                                color: _bodyColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(
                              height: 4,
                            ), // ADJUST: Space between label and number
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _makePhoneCall('08169838619'),
                                    child: Text(
                                      '08169838619',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.blue.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.content_copy,
                                    size: 16,
                                    color: Colors.blue.shade600,
                                  ),
                                  onPressed: () => _copyToClipboard(
                                    '08169838619',
                                    'Phone number copied!',
                                  ),
                                  padding: EdgeInsets
                                      .zero, // ADJUST: Remove button padding
                                  constraints: const BoxConstraints(
                                    minWidth: 30,
                                  ), // ADJUST: Button size
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20), // ADJUST: Space above close button
                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ), // ADJUST: Button padding
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16, // ADJUST: Button text size
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.fixed,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUserLoggedIn) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _pageBackground,
        appBar: AppBar(
          backgroundColor: _surfaceColor,
          surfaceTintColor: Colors.transparent,
          elevation: 1,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: _titleColor),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Edit Profile',
            style: TextStyle(color: _titleColor, fontWeight: FontWeight.w700),
          ),
          centerTitle: false,
          actions: [
            if (!_hasInternetConnection)
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Icon(
                  Icons.wifi_off,
                  color: Colors.orange.shade600,
                  size: 20,
                ),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildProfilePicture(),
              const SizedBox(height: 30),
              if (!_hasInternetConnection) _buildOfflineWarning(),
              _buildToggleSection(),
              const SizedBox(height: 30),
              _isEditMode ? _buildPersonalDetailsForm() : _buildPasswordForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePicture() {
    final avatarUrl = _userData['avatar'] ?? '';
    final fullAvatarUrl = avatarUrl.isNotEmpty && avatarUrl.startsWith('http')
        ? avatarUrl
        : '${ApiEndpoints.baseUrl}$avatarUrl';

    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blue.shade400, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: fullAvatarUrl.isNotEmpty
                ? Image.network(
                    fullAvatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildDefaultAvatar(),
                  )
                : _buildDefaultAvatar(),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Profile picture from your account',
          style: TextStyle(fontSize: 12, color: _bodyColor),
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.orange.shade300],
        ),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 40),
    );
  }

  Widget _buildOfflineWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isDark
            ? Colors.orange.withOpacity(0.12)
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDark
              ? Colors.orange.withOpacity(0.24)
              : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.orange.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You are offline. Changes will be saved locally and synced when online.',
              style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.18 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleOption(
              'Personal Details',
              _isEditMode,
              () => setState(() => _isEditMode = true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildToggleOption(
              'Password',
              !_isEditMode,
              () => setState(() => _isEditMode = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String title, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.shade600
              : (_isDark ? _secondarySurfaceColor : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : _bodyColor,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalDetailsForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildSectionHeader('Personal Information'),
          const SizedBox(height: 16),
          _buildTextField(
            _nameController,
            'Full Name',
            Icons.person_outline,
            _validateName,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _emailController,
            'Email Address',
            Icons.email_outlined,
            _validateEmail,
            enabled: false,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _phoneController,
            'Phone Number',
            Icons.phone_outlined,
            _validatePhone,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _locationController,
            'Location',
            Icons.location_on_outlined,
            _validateLocation,
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('About Me'),
          const SizedBox(height: 16),
          _buildBioField(),
          const SizedBox(height: 40),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildPasswordForm() {
    final bool hasPassword =
        _userData['has_password'] == true ||
        _userData['login_method'] == 'email';

    return Form(
      key: _passwordFormKey,
      child: Column(
        children: [
          _buildSectionHeader(hasPassword ? 'Change Password' : 'Set Password'),
          const SizedBox(height: 16),

          if (hasPassword) ...[
            _buildPasswordField(
              controller: _currentPasswordController,
              label: 'Current Password',
              obscureText: _obscureCurrentPassword,
              onToggleVisibility: () => setState(
                () => _obscureCurrentPassword = !_obscureCurrentPassword,
              ),
            ),
            const SizedBox(height: 16),
          ],

          _buildPasswordField(
            controller: _newPasswordController,
            label: 'New Password',
            obscureText: _obscureNewPassword,
            onToggleVisibility: () =>
                setState(() => _obscureNewPassword = !_obscureNewPassword),
          ),
          const SizedBox(height: 16),

          _buildPasswordField(
            controller: _confirmPasswordController,
            label: 'Confirm New Password',
            obscureText: _obscureConfirmPassword,
            onToggleVisibility: () => setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword,
            ),
            validator: _validateConfirmPassword,
          ),
          const SizedBox(height: 24),

          _buildPasswordRequirements(hasPassword: hasPassword),
          const SizedBox(height: 24),

          if (hasPassword) ...[
            _buildForgotPasswordLink(),
            const SizedBox(height: 30),
          ],

          _buildChangePasswordButton(hasPassword: hasPassword),
        ],
      ),
    );
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your name';
    if (value.length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your email';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value))
      return 'Please enter a valid email';
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your phone number';
    if (value.length < 10) return 'Please enter a valid phone number';
    return null;
  }

  String? _validateLocation(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your location';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty)
      return 'Please confirm your new password';
    if (value != _newPasswordController.text) return 'Passwords do not match';
    return null;
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    String? Function(String?) validator, {
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: enabled ? _bodyColor : _mutedColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _isDark ? _borderColor : Colors.grey.shade400,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _isDark ? _borderColor : Colors.grey.shade300,
          ),
        ),
        filled: true,
        fillColor: enabled
            ? _surfaceColor
            : (_isDark ? _secondarySurfaceColor : Colors.grey.shade100),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: TextStyle(color: enabled ? _bodyColor : _mutedColor),
      ),
      style: TextStyle(fontSize: 16, color: enabled ? _titleColor : _bodyColor),
      validator: validator,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.lock_outline, color: _bodyColor),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: _bodyColor,
          ),
          onPressed: onToggleVisibility,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _isDark ? _borderColor : Colors.grey.shade400,
          ),
        ),
        filled: true,
        fillColor: _surfaceColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: TextStyle(color: _bodyColor),
      ),
      style: TextStyle(fontSize: 16, color: _titleColor),
      validator:
          validator ??
          (value) {
            if (value == null || value.isEmpty)
              return 'Please enter your $label';
            if (value.length < 6)
              return 'Password must be at least 6 characters';
            return null;
          },
    );
  }

  Widget _buildPasswordRequirements({bool hasPassword = true}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDark ? Colors.blue.withOpacity(0.12) : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDark ? Colors.blue.withOpacity(0.22) : Colors.blue.shade100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade600, size: 18),
              const SizedBox(width: 8),
              Text(
                hasPassword ? 'Change Password' : 'Set Password',
                style: TextStyle(
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasPassword
                ? '• Enter your current password\n• New password must be at least 6 characters\n• Confirm your new password'
                : '• Create a new password\n• Must be at least 6 characters\n• Confirm your new password',
            style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildForgotPasswordLink() {
    return GestureDetector(
      onTap: _showForgotPasswordDialog,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isDark
              ? Colors.orange.withOpacity(0.12)
              : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isDark
                ? Colors.orange.withOpacity(0.22)
                : Colors.orange.shade100,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.help_outline, color: Colors.orange.shade600, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Contact management for assistance',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          height: 20,
          width: 4,
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _titleColor,
          ),
        ),
      ],
    );
  }

  Widget _buildBioField() {
    return TextFormField(
      controller: _bioController,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: 'About Me',
        alignLabelWithHint: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _isDark ? _borderColor : Colors.grey.shade400,
          ),
        ),
        filled: true,
        fillColor: _surfaceColor,
        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        labelStyle: TextStyle(color: _bodyColor),
      ),
      style: TextStyle(fontSize: 16, color: _titleColor),
      validator: (value) {
        if (value == null || value.isEmpty)
          return 'Please tell us about yourself';
        if (value.length < 10) return 'Please write a bit more about yourself';
        return null;
      },
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          shadowColor: Colors.blue.shade300,
        ),
        child: _isSaving
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Saving...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _hasInternetConnection ? 'Save Changes' : 'Save Offline',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildChangePasswordButton({bool hasPassword = true}) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isChangingPassword ? null : _changePassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          shadowColor: Colors.blue.shade300,
        ),
        child: _isChangingPassword
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Updating...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    hasPassword ? Icons.lock_reset_rounded : Icons.lock_outline,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _hasInternetConnection
                        ? (hasPassword ? 'Change Password' : 'Set Password')
                        : (hasPassword
                              ? 'Change Password Offline'
                              : 'Set Password Offline'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

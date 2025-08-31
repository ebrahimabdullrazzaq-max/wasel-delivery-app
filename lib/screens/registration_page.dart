// screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'login_page.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  Position? _selectedLocation;
  String? _deliveryAddress;

  @override
  void initState() {
    super.initState();
    _phoneController.text = '+967 ';
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _error = 'Location services are disabled.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _error = 'Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _error = 'Location permission permanently denied.');
    }
  }

  Future<void> _selectLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      String address = 'Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        address = [place.street, place.locality, place.postalCode]
            .where((part) => part != null && part.isNotEmpty)
            .join(', ');
      }

      setState(() {
        _selectedLocation = position;
        _deliveryAddress = address;
        _addressController.text = address;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Failed to get location: $e');
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || _selectedLocation == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final result = await authProvider.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        confirmPassword: _confirmPasswordController.text.trim(),
        phone: _phoneController.text.trim(),
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
        address: _addressController.text.trim(),
      );

      if (result['success']) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('address', _addressController.text.trim());
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() => _error = result['message']);
      }
    } catch (e) {
      setState(() => _error = 'Email or phone number already exists. Please try another.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Phone is required';
    if (!value.startsWith('+967')) return 'Must start with +967';
    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 9) return 'Enter a valid Yemeni number';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Color(0xFF0D47A1), // Navy Blue
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              // App Logo
              Image.asset(
                'assets/images/logo.png', // ✅ Replace with your logo path
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              Text(
                "Welcome to Wasel",
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF0D47A1),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),

              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Full Name
                    _buildInputField(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.person,
                      validator: (v) => v?.isEmpty == true ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Email
                    _buildInputField(
                      controller: _emailController,
                      label: 'Email Address',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v?.isEmpty == true ? 'Email is required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Phone
                    _buildInputField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone,
                      validator: _validatePhone,
                    ),
                    const SizedBox(height: 16),

                    // Password
                    _buildInputField(
                      controller: _passwordController,
                      label: 'Password',
                      icon: Icons.lock,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (v) => v!.length < 8 ? 'At least 8 characters' : null,
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password
                    _buildInputField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      validator: (v) => v != _passwordController.text ? 'Passwords don’t match' : null,
                    ),
                    const SizedBox(height: 16),

                    // Address
                    _buildInputField(
                      controller: _addressController,
                      label: 'Delivery Address',
                      icon: Icons.location_on,
                      maxLines: 2,
                      validator: (v) => v?.isEmpty == true ? 'Address is required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Select Location Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _selectLocation,
                        icon: const Icon(Icons.location_on, size: 18),
                        label: Text(
                          _selectedLocation == null ? 'Select Location' : 'Change Location',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF0D47A1),
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Selected Address Display
                    if (_deliveryAddress != null)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Color(0xFF0D47A1)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _deliveryAddress!,
                                style: TextStyle(fontSize: 14, color: Colors.black87),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Error Message
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xFFC62828).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Color(0xFFC62828), width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Color(0xFFC62828), size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Color(0xFFC62828),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Register Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFC62828), // Red
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                        ),
                        child: _loading
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'REGISTER',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Login Link
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => LoginScreen()),
                        );
                      },
                      child: Text(
                        "Already have an account? Log in",
                        style: TextStyle(
                          color: Color(0xFF0D47A1),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType? keyboardType,
    int? maxLines,
    String? Function(String?)? validator,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines ?? 1,
          obscureText: obscureText,
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Color(0xFF0D47A1).withOpacity(0.7)),
            prefixIcon: icon != null
                ? Icon(icon, color: Color(0xFF0D47A1), size: 20)
                : null,
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          ),
          style: TextStyle(fontSize: 16, color: Colors.black),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
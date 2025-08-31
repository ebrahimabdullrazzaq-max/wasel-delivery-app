// pages/edit_account_page.dart
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'account_details_page.dart';

class EditAccountPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const EditAccountPage({Key? key, required this.user}) : super(key: key);

  @override
  _EditAccountPageState createState() => _EditAccountPageState();
}

class _EditAccountPageState extends State<EditAccountPage> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  bool _loading = false;
  String? _error;

  LatLng? _selectedLocation;
  String _deliveryAddress = '';
  GoogleMapController? _mapController;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['name']);
    _phoneController = TextEditingController(text: widget.user['phone']);
    _addressController = TextEditingController(text: widget.user['address'] ?? '');

    if (widget.user['latitude'] != null && widget.user['longitude'] != null) {
      _selectedLocation = LatLng(
        widget.user['latitude'] is double
            ? widget.user['latitude']
            : double.parse(widget.user['latitude'].toString()),
        widget.user['longitude'] is double
            ? widget.user['longitude']
            : double.parse(widget.user['longitude'].toString()),
      );
      _deliveryAddress = widget.user['address'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _selectLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _error = 'Location services are disabled.';
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _error = 'Location permission denied.';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _error = 'Location permission denied permanently.';
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String address = 'Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        address = [
          place.street,
          place.subLocality,
          place.locality,
          place.postalCode,
        ].where((part) => part != null && part!.isNotEmpty).join(', ');
      }

      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _deliveryAddress = address;
        _addressController.text = address;
        _error = null;
      });

      if (_mapController != null && mounted) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(position.latitude, position.longitude),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to get your location: ${e.toString()}';
      });
    }
  }

  Future<void> _updateAccount() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocation == null) {
      setState(() {
        _error = 'Please select a delivery location';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      final response = await http.put(
        Uri.parse('http://192.168.43.181:8000/api/user'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _deliveryAddress,
          'latitude': _selectedLocation!.latitude,
          'longitude': _selectedLocation!.longitude,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final updatedUser = {
          ...widget.user,
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _deliveryAddress,
          'latitude': _selectedLocation!.latitude,
          'longitude': _selectedLocation!.longitude,
        };

        authProvider.updateUser(updatedUser);

        if (!mounted) return;
        Navigator.pop(context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AccountDetailsPage(user: updatedUser),
          ),
        );
      } else {
        setState(() {
          _error = data['message'] ?? 'Update failed';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Account',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Color(0xFF0D47A1), // Navy Blue
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        color: Color(0xFFF8F9FA), // Light gray background
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              // Error Banner
              if (_error != null)
                Container(
                  padding: EdgeInsets.all(14),
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Color(0xFFC62828).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFFC62828), width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Color(0xFFC62828), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Color(0xFFC62828),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.start,
                        ),
                      ),
                    ],
                  ),
                ),

              // Name Field
              _buildInputField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Name is required';
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Phone Field
              _buildInputField(
                controller: _phoneController,
                label: 'Phone Number',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Phone is required';
                  if (!value.startsWith('+967')) return 'Must start with +967';
                  final digits = value.replaceAll(RegExp(r'[^\d]'), '');
                  if (digits.length < 9) return 'Enter a valid Yemeni number';
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Address Field
              _buildInputField(
                controller: _addressController,
                label: 'Delivery Address',
                icon: Icons.location_on,
                maxLines: 3,
                onChanged: (value) => _deliveryAddress = value,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Address is required';
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Map Section
              Text(
                'Select Delivery Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
              SizedBox(height: 8),
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _selectedLocation ??
                          LatLng(15.3694, 44.1910), // Dhamar, Yemen
                      zoom: 15,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    onTap: (location) {
                      setState(() {
                        _selectedLocation = location;
                      });
                      _getAddressFromCoordinates(location);
                    },
                    markers: {
                      if (_selectedLocation != null)
                        Marker(
                          markerId: MarkerId('selected_location'),
                          position: _selectedLocation!,
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                        ),
                    },
                  ),
                ),
              ),
              SizedBox(height: 12),

              // Use My Location Button
              Center(
                child: ElevatedButton.icon(
                  onPressed: _selectLocation,
                  icon: Icon(Icons.location_searching, size: 18),
                  label: Text('Use My Current Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0D47A1),
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Save Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : _updateAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFC62828), // Red
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                    textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                          'SAVE CHANGES',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
    void Function(String)? onChanged,
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
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Color(0xFF0D47A1).withOpacity(0.7)),
            prefixIcon: icon != null
                ? Icon(icon, color: Color(0xFF0D47A1), size: 20)
                : null,
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

  Future<void> _getAddressFromCoordinates(LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        String address = [
          place.street,
          place.subLocality,
          place.locality,
          place.postalCode,
        ].where((part) => part != null && part!.isNotEmpty).join(', ');

        setState(() {
          _deliveryAddress = address;
          _addressController.text = address;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _deliveryAddress = 'Location: ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
          _addressController.text = _deliveryAddress;
        });
      }
    }
  }
}
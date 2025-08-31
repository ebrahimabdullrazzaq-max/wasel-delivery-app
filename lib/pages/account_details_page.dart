// pages/account_details_page.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'edit_account_page.dart';

class AccountDetailsPage extends StatelessWidget {
  const AccountDetailsPage({Key? key, required Map<String, dynamic> user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.user == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Account Details'),
              backgroundColor: Color(0xFF0D47A1), // Navy Blue
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.1),
            ),
            body: const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1))),
          );
        }

        final user = authProvider.user!;
        final location = (user['latitude'] != null && user['longitude'] != null)
            ? LatLng(
                _parseDouble(user['latitude']),
                _parseDouble(user['longitude']),
              )
            : null;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Account Details'),
            backgroundColor: Color(0xFF0D47A1), // Navy Blue
            elevation: 2,
            shadowColor: Colors.black.withOpacity(0.1),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditAccountPage(user: user),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Container(
            color: Color(0xFFF8F9FA), // Light gray background
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Personal Information Section
                  _buildSectionTitle('Personal Information'),
                  const SizedBox(height: 8),
                  _buildInfoTile('Name', user['name']),
                  _buildInfoTile('Email', user['email'] ?? 'Not provided'),
                  _buildInfoTile('Phone', user['phone']),
                  _buildInfoTile('Address', user['address']),

                  const SizedBox(height: 32),

                  // Delivery Location Section
                  _buildSectionTitle('Delivery Location'),
                  const SizedBox(height: 12),
                  Container(
                    height: 240,
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
                      child: location != null
                          ? GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: location,
                                zoom: 15,
                              ),
                              markers: {
                                Marker(
                                  markerId: const MarkerId('user_location'),
                                  position: location,
                                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                                  infoWindow: InfoWindow(
                                    title: 'Your Location',
                                    snippet: user['address'],
                                  ),
                                ),
                              },
                              mapType: MapType.normal,
                              myLocationEnabled: false,
                              zoomControlsEnabled: true,
                              compassEnabled: false,
                            )
                          : const Center(
                              child: Text(
                                'Location not set',
                                style: TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0D47A1), // Navy Blue
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String? value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 1,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF0D47A1).withOpacity(0.8),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                value ?? 'Not provided',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
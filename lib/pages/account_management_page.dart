// pages/account_management_page.dart
import 'package:flutter/material.dart';
import 'package:wasel/utils/cart_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import 'my_orders_page.dart';
import 'edit_account_page.dart';
import 'account_details_page.dart';
import 'package:wasel/screens/login_page.dart';


class AccountManagementPage extends StatefulWidget {
  final String initialCity; // ✅ Receive current city
  final Function(String city)? onCityChanged;

  const AccountManagementPage({
    Key? key,
    this.initialCity = 'Dhamar',
    this.onCityChanged,
  }) : super(key: key);

  @override
  _AccountManagementPageState createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<AccountManagementPage> {
  late String selectedCity; // ✅ Use 'late' so we can set it in initState
  List<String> availableCities = ['Dhamar', 'Sana\'a', 'Taiz', 'Aden', 'Hodeidah'];

  final List<Map<String, dynamic>> options = [
    {'icon': Icons.person, 'title': 'My Account', 'route': 'edit_account'},
    {'icon': Icons.shopping_cart, 'title': 'My Orders', 'route': 'my_orders'},
    {'icon': Icons.location_on, 'title': 'Change City', 'route': 'change_city'},
    {'icon': Icons.exit_to_app, 'title': 'Logout', 'route': 'logout'},
    {'icon': Icons.delete, 'title': 'Delete Account', 'route': 'delete_account'},
  ];

  @override
  void initState() {
    super.initState();
    selectedCity = widget.initialCity; // ✅ Set initial city from parent
  }

  @override
  void didUpdateWidget(covariant AccountManagementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCity != widget.initialCity) {
      setState(() {
        selectedCity = widget.initialCity; // ✅ Update if city changes externally
      });
    }
  }

void _navigateTo(String route) {
  switch (route) {
    case 'edit_account':
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      if (user != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AccountDetailsPage(user: user),
          ),
        );
      }
      break;

    case 'my_orders':
      // ✅ Pass current selected city to MyOrdersPage
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MyOrdersPage(currentCity: selectedCity),
        ),
      );
      break;

    case 'change_city':
      _showChangeCityDialog();
      break;
    case 'logout':
      _showLogoutDialog();
      break;
    case 'delete_account':
      _showDeleteAccountDialog();
      break;
  }
}


void _showChangeCityDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Change City'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: availableCities.map((city) {
          return ListTile(
            title: Text(city),
            leading: Icon(Icons.location_on),
            onTap: () async {
              Navigator.pop(context);

              // ✅ Save new city
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('selected_city', city);

              // ❌ Don't clear cart anymore (each city keeps its own cart)
              // await CartManager.clearCart();

              // ✅ Update UI
              if (mounted) {
                setState(() {
                  selectedCity = city;
                });
              }

              // ✅ Notify parent (like HomePage)
              if (widget.onCityChanged != null) {
                widget.onCityChanged!(city);
              }

              // ✅ Show message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Switched to $city')),
              );
            },
          );
        }).toList(),
      ),
    ),
  );
}


  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirm Logout',
          style: TextStyle(
            color: Color(0xFF0D47A1),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFC62828), // Red
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Logout',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Account',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text('Are you sure you want to delete your account? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final token = authProvider.token;

              if (token == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('You are not logged in.')),
                );
                return;
              }

              final result = await authProvider.deleteAccount(token);

              if (result['success']) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Your account has been deleted successfully.'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
                Navigator.pushReplacementNamed(context, '/login');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete account: ${result['message']}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(
              'Delete Account',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF0D47A1), // Navy Blue
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        title: Text(
          'Account Management',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current City Banner
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFF0D47A1), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Current City: $selectedCity',
                    style: TextStyle(
                      color: Color(0xFF0D47A1),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Icon(Icons.location_on, color: Color(0xFFC62828), size: 20),
                ],
              ),
            ),
            SizedBox(height: 20),
            // Options Grid
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  return GestureDetector(
                    onTap: () => _navigateTo(option['route']),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Color(0xFF0D47A1), // Navy Blue background
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              option['icon'],
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            option['title'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D47A1),
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 
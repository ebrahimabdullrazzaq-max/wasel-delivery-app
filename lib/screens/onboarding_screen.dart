// screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wasel/screens/login_page.dart';

class OnboardingScreen extends StatefulWidget {
  static const String route = '/onboarding';

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _slides = [
    {
      'title': 'Welcome to Wasel',
      'subtitle': 'Your favorite food delivered fast and fresh.',
      'image': 'assets/images/onboarding_1.png',
    },
    {
      'title': 'Order from Any Store',
      'subtitle': 'Choose from top-rated restaurants and groceries.',
      'image': 'assets/images/onboarding_2.png',
    },
    {
      'title': 'Track Your Order',
      'subtitle': 'Know exactly where your delivery is in real-time.',
      'image': 'assets/images/onboarding_3.png',
    },
  ];

  Future<void> _markOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasOnboarded', true);
  }

  void _onSkip() {
    _markOnboarded();
    Navigator.pushReplacementNamed(context, '/home');
  }

  void _onNext() {
    if (_currentPage == _slides.length - 1) {
      _markOnboarded();
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      _pageController.nextPage(
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Page View
          PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final item = _slides[index];
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Image
                    SizedBox(
                      height: 200,
                      child: Image.asset(
                        item['image']!,
                        fit: BoxFit.contain,
                      ),
                    ),

                    // Title & Subtitle (moved up)
                    SizedBox(height: 24),
                    Text(
                      item['title']!,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      item['subtitle']!,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),

          // Dots Indicator
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _slides.map((slide) {
                int index = _slides.indexOf(slide);
                return Container(
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Color(0xFF0D47A1)
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Skip / Done Button
          Positioned(
            bottom: 40,
            right: 20,
            child: TextButton(
              onPressed: _onSkip,
              child: Text(
                _currentPage == _slides.length - 1 ? 'Done' : 'Skip',
                style: TextStyle(
                  color: Color(0xFF0D47A1),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Next Button (small circle arrow)
          Positioned(
            bottom: 40,
            left: 20,
            child: FloatingActionButton(
              backgroundColor: Color(0xFFC62828),
              onPressed: _onNext,
              child: Icon(
                _currentPage == _slides.length - 1 ? Icons.check : Icons.arrow_forward,
                color: Colors.white,
              ),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
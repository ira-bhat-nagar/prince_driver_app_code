import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback? onGetStarted;

  const SplashScreen({
    super.key,
    this.onGetStarted,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-navigation removed. Waiting for user to click 'Get Started'.
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF030B1C),
      body: Stack(
        children: [
            // Premium midnight studio background, matching the landing reference.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF061126), Color(0xFF0A1E45), Color(0xFF020916)],
                    stops: [0, .55, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -90,
              bottom: screenHeight * .22,
              child: Container(
                width: 230,
                height: 330,
                decoration: BoxDecoration(
                  color: const Color(0xFF1769FF).withOpacity(.22),
                  borderRadius: BorderRadius.circular(180),
                  boxShadow: [BoxShadow(color: const Color(0xFF1769FF).withOpacity(.55), blurRadius: 80, spreadRadius: 28)],
                ),
              ),
            ),
            Positioned.fill(
              child: Image.asset(
                'assets/gorush_driver_hero_v2.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),

            // Soft atmospheric gradient overlay for readability
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.40, 0.70, 1.0],
                    colors: [
                      Color(0x22030B1C),
                      Color(0x12030B1C),
                      Color(0x22030B1C),
                      Color(0xF8030B1C),
                    ],
                  ),
                ),
              ),
            ),

            // Content Overlay
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 16),
                child: Column(
                  children: [
                    SizedBox(height: screenHeight > 600 ? screenHeight * 0.105 : 42),

                    // Top Branding: GoRush Circular Logo + Title
                    _buildGoRushPinLogo(),
                    const SizedBox(height: 28),
                    const Text(
                      'GoRush',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 45,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .2,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Driver App',
                      style: TextStyle(
                        color: Color(0xFF93C5FD), // Soft Sky Blue
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Drive • Earn • Grow',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 16,
                        letterSpacing: 3.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const Spacer(),

                    // Bottom CTA: Get Started
                    ElevatedButton(
                      onPressed: widget.onGetStarted,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2864E8),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(64),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 10,
                        shadowColor: const Color(0xFF1D60FF).withOpacity(0.5),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Get Started',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 10),
                          Icon(Icons.arrow_forward_rounded, size: 24),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Trust Tagline
                    const Text(
                      'Trusted by 50,000+ Drivers Across NCR',
                      style: TextStyle(
                        color: Color(0xFF7C8AA5),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildGoRushPinLogo() {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22C55E).withOpacity(0.4),
          blurRadius: 26,
          spreadRadius: 3,
          offset: const Offset(0, 7),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.88), width: 3),
      ),
      child: const Center(
        child: Icon(
          Icons.directions_car_filled_rounded,
          color: Colors.white,
          size: 46,
        ),
      ),
    );
  }

}

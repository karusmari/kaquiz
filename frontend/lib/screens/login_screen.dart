import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/api_service.dart';
import '../screens/map_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
    scopes: ['email', 'profile'],
  );
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      print("🔐 Starting Google Sign-In process...");

      // Clear any previous Google session so the account chooser is shown again.
      await _googleSignIn.signOut();
      print("✅ Signed out previous session");

      // 1. Google sisselogimise aken
      print("🔄 Calling GoogleSignIn.signIn()...");
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      print("✅ Got Google user: ${googleUser?.email}");

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // Kasutaja tühistas sisselogimise
      }

      // 2. Hankige Google'ilt ID Token
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      // 3. Saada see oma Go backendile
      final String? jwtToken = await _apiService.loginWithGoogle(idToken);

      if (jwtToken != null) {
        final profile = await _apiService.getMyProfile();
        final avatarUrl = profile?['avatar'] as String?;

        print("Login successful! Token: $jwtToken");
        if (!mounted) return;

        // NEXT STEP: Navigate to Map screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MapScreen(initialAvatarUrl: avatarUrl),
          ),
        );
      }
    } catch (error, stackTrace) {
      print("❌ ERROR logging in: $error");
      print("📍 Stack trace: $stackTrace");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Login failed: $error",
            style: TextStyle(fontSize: 16, color: Colors.red),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color.fromARGB(255, 240, 234, 242),
              const Color.fromARGB(255, 196, 183, 196),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Hero(
                        tag: 'app-logo',
                        child: Image.asset(
                          'assets/logo.png',
                          height: 200,
                          errorBuilder: (context, error, stackTrace) {
                            // Placeholder kui logo pole olemas
                            return CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.location_on,
                                size: 50,
                                color: Colors.blue.shade900,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Google Sign-In Button
                      ElevatedButton.icon(
                        icon: Image.network(
                          'https://pngimg.com/uploads/google/google_PNG19635.png',
                          height: 20,
                        ),
                        label: const Text("Continue with Google Login"),
                        onPressed: _handleGoogleSignIn,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 10,
                          ),
                          backgroundColor: Colors.white,
                          foregroundColor: const Color.fromARGB(179, 95, 90, 90),
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Privacy notice
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          "Your location is stored securely and only shared with your approved friends.",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color.fromARGB(179, 95, 90, 90),
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

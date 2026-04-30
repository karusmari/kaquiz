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
      } else {
        throw Exception("Backend did not return a token");
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
      appBar: AppBar(title: const Text("KaQuiz Login")),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Welcome to KaQuiz!",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    icon: Image.network(
                      'https://pngimg.com/uploads/google/google_PNG19635.png',
                      height: 24,
                    ),
                    label: const Text("Log in with Google"),
                    onPressed: _handleGoogleSignIn,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

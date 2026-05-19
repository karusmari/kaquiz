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
  // Setup Google Sign-In instance configuration using client IDs in .env
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
    scopes: ['email', 'profile'],
  );
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  // Handles the complete authentication flow
  // Google Account picker -> google verification token -> custon BE validation -> navigation to MapScreen
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      print("Starting Google Sign-In flow...");

      // Clear any previous Google session so the account chooser is shown again.
      await _googleSignIn.signOut();
      
      // open the native Google Sign-In dialog and let user pick an account. This also handles the OAuth flow and returns a GoogleSignInAccount on success.
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // if user dismisses or cancels the login dialog screen, exit safely without error
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; 
      }
      
      print("Got Google user: ${googleUser.email}");

      // Grab authentication tokens (specifically the ID token) from the GoogleSignInAccount which will be sent to our backend for verification and JWT issuance.
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      // forward the Google ID token to our backend API to validate it and exchange for our own JWT token for authenticated API access. 
      // The backend will verify the token with Google's services and create a user session if valid. 
      final String? jwtToken = await _apiService.loginWithGoogle(idToken);

      if (jwtToken != null) {
      print("Login successful! Token: $jwtToken");

      // safety guard to prevent async operations from the interacting with the view context if the screen was destroyed
      if (!mounted) return;

      // getting the avatar URL from the Google user profile to pass to the MapScreen for initial display
      final String? avatarUrl = googleUser.photoUrl;

        // Navigate to the MapScreen and pass the avatar URL for display. 
        // We use pushReplacement to remove the LoginScreen from the navigation stack so user can't go back to it with the back button.
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

      // UI feedback for login failure with error details.
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
      // always reset progress indicators when the execution chain closes out 
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

import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// all the queries to the backend will be made here, so that we can easily change the base url if needed and also handle errors in one place
class ApiService {
  final String baseUrl = dotenv.env['BASE_URL'] ?? "http://localhost:8080";
  final _storage = const FlutterSecureStorage();

  Future<String?> loginWithGoogle(String? idToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth'),
        headers: {
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "true",
        },
        body: jsonEncode({"id_token": idToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];

        if (token != null) {
          await _storage.write(
            key: 'jwt_token',
            value: token,
          ); // Save token securely
        }
        return token;
      } else {
        print(
          'Google login failed with status: ${response.statusCode}, body: ${response.body}',
        );
        return null;
      }
    } catch (e) {
      print('Error during login: $e');
      return null;
    }
  }

  // sending the location. Thats the one to call every 5 seconds.
  Future<bool> updateLocation(double latitude, double longitude) async {
    try {
      String? token = await _storage.read(key: 'jwt_token');
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/api/location'),
        headers: {
          "authorization": token,
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "true",
        },
        body: jsonEncode({"latitude": latitude, "longitude": longitude}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Location update error: $e");
      return false;
    }
  }

  // searching the user by email
  Future<Map<String, dynamic>?> searchUserByEmail(String email) async {
    try {
      String? token = await _storage.read(key: 'jwt_token');
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/search?email=$email'),
        headers: {
          "authorization": token ?? "", // sending the token for authentication
          "ngrok-skip-browser-warning": "true",
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body); // Returns {"id": X, "email": "..."}
      }
      return null;
    } catch (e) {
      print("Search error: $e");
      return null;
    }
  }

  // sending an invite via user ID (Swagger: POST /invites/{user_id})
  Future<bool> sendInvite(int userId, String token) async {
    try {
      String? token = await _storage.read(key: 'jwt_token');
      final response = await http.post(
        Uri.parse('$baseUrl/api/invites/$userId'),
        headers: {
          "authorization": token ?? "", // sending the token for authentication
          "ngrok-skip-browser-warning": "true",
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Invite error: $e");
      return false;
    }
  }
}

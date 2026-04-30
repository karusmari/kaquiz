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
          'Login failed with status: ${response.statusCode}, body: ${response.body}',
        );
        return null;
      }
    } catch (e) {
      print('Error during login: $e');
      return null;
    }
  }

  // Fetch current logged-in user's profile.
  Future<Map<String, dynamic>?> getMyProfile() async {
    try {
      String? token = await _storage.read(key: 'jwt_token');
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/users/me'),
        headers: {"authorization": token, "ngrok-skip-browser-warning": "true"},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      print(
        'Get profile failed with status: ${response.statusCode}, body: ${response.body}',
      );
      return null;
    } catch (e) {
      print('Get profile error: $e');
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

  // Update the logged-in user's profile fields.
  Future<Map<String, dynamic>?> updateUserProfile({
    String? name,
    String? avatar,
  }) async {
    try {
      String? token = await _storage.read(key: 'jwt_token');
      if (token == null) return null;

      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (avatar != null) body['avatar'] = avatar;

      final response = await http.put(
        Uri.parse('$baseUrl/api/users'),
        headers: {
          "authorization": token,
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "true",
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      print(
        'Update profile failed with status: ${response.statusCode}, body: ${response.body}',
      );
      return null;
    } catch (e) {
      print('Update profile error: $e');
      return null;
    }
  }

  // searching the user by email
  Future<Map<String, dynamic>?> searchUserByEmail(String email) async {
    try {
      String? token = await _storage.read(key: 'jwt_token');
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/users/search?email=${Uri.encodeQueryComponent(email)}',
        ),
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
  Future<bool> sendInvite(int userId) async {
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

  // Decode JWT stored in secure storage and return `user_id` claim if present
  Future<int?> getCurrentUserId() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) return null;
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      // Base64 decode (add padding if necessary)
      String normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final Map<String, dynamic> map = jsonDecode(decoded);
      if (map.containsKey('user_id')) {
        return (map['user_id'] is int)
            ? map['user_id'] as int
            : (map['user_id'] as num).toInt();
      }
      return null;
    } catch (e) {
      print('Failed to decode JWT: $e');
      return null;
    }
  }

  // fetching friends' locations
  Future<List<dynamic>?> getFriendsLocations() async {
    try {
      String? token = await _storage.read(key: 'jwt_token');
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/friends'),
        headers: {"authorization": token, "ngrok-skip-browser-warning": "true"},
      );

      if (response.statusCode == 200) {
        return jsonDecode(
          response.body,
        ); // Returns list of locations with user_id
      }
      return null;
    } catch (e) {
      print("Get friends locations error: $e");
      return null;
    }
  }

  // Delete a friend by ID
  Future<bool> deleteFriend(int friendId) async {
    try {
      String? token = await _storage.read(key: 'jwt_token');
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('$baseUrl/api/friends/$friendId'),
        headers: {"authorization": token, "ngrok-skip-browser-warning": "true"},
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Delete friend error: $e");
      return false;
    }
  }

  // Fetch list of accepted friends with details (name, email)
  // Returns list of {user_id, name, email, ...}
  Future<List<dynamic>?> getFriendsList() async {
    try {
      String? token = await _storage.read(key: 'jwt_token');
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/friends/list'),
        headers: {"authorization": token, "ngrok-skip-browser-warning": "true"},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print("Get friends list error: $e");
      return null;
    }
  }

  // Fetch pending friend invites (invitations sent to current user)
  Future<List<dynamic>?> getPendingInvites() async {
    try {
      String? token = await _storage.read(key: 'jwt_token');
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/invites/pending'),
        headers: {"authorization": token, "ngrok-skip-browser-warning": "true"},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print("Get pending invites error: $e");
      return null;
    }
  }

  // Accept an invite by friendship ID
  Future<bool> acceptInvite(int friendshipId) async {
    try {
      String? token = await _storage.read(key: 'jwt_token');
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/api/invites/$friendshipId/accept'),
        headers: {
          "authorization": token,
          "Content-Type": "application/json",
          "ngrok-skip-browser-warning": "true",
        },
        body: jsonEncode({"friendship_id": friendshipId}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Accept invite error: $e");
      return false;
    }
  }
}

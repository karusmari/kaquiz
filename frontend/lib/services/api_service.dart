import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// all the queries to the backend will be made here, so that we can easily change the base url if needed and also handle errors in one place
class ApiService {
  final String baseUrl = dotenv.env['BASE_URL'] ?? "http://localhost:8080";
  final _storage = const FlutterSecureStorage();

  // Helper method to get headers with optional authorization
  Future<Map<String, String>> _getAuthHeaders({bool protected = true}) async {
    final Map<String, String> headers = {
      "Content-Type": "application/json",
      "ngrok-skip-browser-warning": "true",
    };

    if (protected) {
      String? token = await _storage.read(key: 'jwt_token');
      if (token != null && token.isNotEmpty) {
        headers["authorization"] = "Bearer $token";
      }
    }
    return headers;
  }

  // Sign out locally by removing the stored JWT
  Future<void> signOut() async {
    await _storage.delete(key: 'jwt_token');
  }

  // If server returns 401, perform client-side sign out and return true
  Future<bool> _handleUnauthorized(int statusCode) async {
    if (statusCode == 401) {
      print('Unauthorized detected — clearing token and signing out locally');
      await signOut();
      return true;
    }
    return false;
  }

  // Login with Google ID token, returns JWT on success
  Future<String?> loginWithGoogle(String? idToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth'),
        headers: await _getAuthHeaders(protected: false),
        body: jsonEncode({"id_token": idToken}),
      );

      if (response.statusCode == 200) {
        final token = jsonDecode(response.body)['token'];

        if (token != null) {
          await _storage.write(
            key: 'jwt_token',
            value: token,
          ); // Save token securely
        }
        return token;
      } else {
        throw Exception(
          'Backend login failed with status ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error during login: $e');
    }
  }

  // Fetch current logged-in user's profile.
  Future<Map<String, dynamic>?> getMyProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/me'),
        headers: await _getAuthHeaders(protected: true),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      // If unauthorized, clear token and let caller handle navigation
      await _handleUnauthorized(response.statusCode);
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
      final response = await http.post(
        Uri.parse('$baseUrl/api/location'),
        headers: await _getAuthHeaders(protected: true),
        body: jsonEncode({"latitude": latitude, "longitude": longitude}),
      );
      if (response.statusCode == 200) return true;
      await _handleUnauthorized(response.statusCode);
      return false;
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
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (avatar != null) body['avatar'] = avatar;

      final response = await http.put(
        Uri.parse('$baseUrl/api/users'),
        headers: await _getAuthHeaders(protected: true),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      await _handleUnauthorized(response.statusCode);
      throw Exception(
        'Update profile failed with status: ${response.statusCode}, body: ${response.body}',
      );
    } catch (e) {
      print('Update profile error: $e');
      return null;
    }
  }

  // searching the user by email
  Future<Map<String, dynamic>?> searchUserByEmail(String email) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/users/search?email=${Uri.encodeQueryComponent(email)}',
        ),
        headers: await _getAuthHeaders(protected: true),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body); // Returns {"id": X, "email": "..."}
      }
      await _handleUnauthorized(response.statusCode);
      return null;
    } catch (e) {
      print("Search error: $e");
      return null;
    }
  }

  // Search users by partial email/name. Returns a list or null.
  Future<List<dynamic>?> searchUsers(String query) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/users/search?email=${Uri.encodeQueryComponent(query)}',
        ),
        headers: await _getAuthHeaders(protected: true),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) return decoded;
        if (decoded is Map) return [decoded];
      }
      await _handleUnauthorized(response.statusCode);
      return null;
    } catch (e) {
      print("Search users error: $e");
      return null;
    }
  }

  // sending an invite via user ID (Swagger: POST /invites/{user_id})
  Future<bool> sendInvite(int userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/invites/$userId'),
        headers: await _getAuthHeaders(protected: true),
      );
      if (response.statusCode == 200) return true;
      await _handleUnauthorized(response.statusCode);
      return false;
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
      final response = await http.get(
        Uri.parse('$baseUrl/api/friends'),
        headers: await _getAuthHeaders(protected: true),
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
      final response = await http.delete(
        Uri.parse('$baseUrl/api/friends/$friendId'),
        headers: await _getAuthHeaders(protected: true),
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
      final response = await http.get(
        Uri.parse('$baseUrl/api/friends/list'),
        headers: await _getAuthHeaders(protected: true),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      await _handleUnauthorized(response.statusCode);
      return null;
    } catch (e) {
      print("Get friends list error: $e");
      return null;
    }
  }

  // Fetch pending friend invites (invitations sent to current user)
  Future<List<dynamic>?> getPendingInvites() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/invites/pending'),
        headers: await _getAuthHeaders(protected: true),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      await _handleUnauthorized(response.statusCode);
      return null;
    } catch (e) {
      print("Get pending invites error: $e");
      return null;
    }
  }

  // Accept an invite by friendship ID
  Future<bool> acceptInvite(int friendshipId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/invites/$friendshipId/accept'),
        headers: await _getAuthHeaders(protected: true),
        body: jsonEncode({"friendship_id": friendshipId}),
      );

      if (response.statusCode == 200) return true;
      await _handleUnauthorized(response.statusCode);
      return false;
    } catch (e) {
      print("Accept invite error: $e");
      return false;
    }
  }

  // Decline an invite by friendship ID
  Future<bool> declineInvite(int friendshipId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/invites/$friendshipId/decline'),
        headers: await _getAuthHeaders(protected: true),
        body: jsonEncode({"friendship_id": friendshipId}),
      );

      if (response.statusCode == 200) return true;
      await _handleUnauthorized(response.statusCode);
      return false;
    } catch (e) {
      print("Decline invite error: $e");
      return false;
    }
  }
}

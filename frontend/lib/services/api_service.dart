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
        headers["Authorization"] = "Bearer $token";
      }
    }
    return headers;
  }

  // Sign out locally by removing the stored JWT
  Future<void> signOut() async {
    try {
      // inform the server about sign out to revoke the token if needed
      await http.post(
        Uri.parse('$baseUrl/api/signout'),
        headers: await _getAuthHeaders(protected: true),
      );
    } catch (e) {
      // Sign-out request failed; swallow and continue to clear local token
    } finally {
      // deleting the token locally regardless of server response to ensure user is signed out on client side
      await _storage.delete(key: 'jwt_token');
  }
  }

  // If server returns 401, perform client-side sign out and return true
  Future<bool> _handleUnauthorized(int statusCode) async {
    if (statusCode == 401) {
      // Unauthorized detected — clear token and sign out locally
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
      return null;
    } catch (e) {
      // Get profile error: handled by returning null
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
        // Location update error: handled by returning false
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
        // Update profile error: handled by returning null
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
        // Search users error: handled by returning null
      return null;
    }
  }

  // sending an invite via user ID 
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
        // Invite error: handled by returning false
      return false;
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
        // Get friends locations error: handled by returning null
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
        // Delete friend error: handled by returning false
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
        // Get friends list error: handled by returning null
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
        // Get pending invites error: handled by returning null
      return null;
    }
  }

  // Accept an invite by friendship ID
  Future<bool> acceptInvite(int friendshipId) async {
    try {
      final headers = await _getAuthHeaders(protected: true);
      headers['Content-Type'] = 'application/json';

      final url = '$baseUrl/api/invites/accept/$friendshipId';

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({'friendship_id': friendshipId}),
      );

      if (response.statusCode == 200) return true;
      await _handleUnauthorized(response.statusCode);
      return false;
    } catch (e) {
        // Accept invite error: handled by returning false
      return false;
    }
  }

  // Decline an invite by friendship ID
  Future<bool> declineInvite(int friendshipId) async {
    try {
        final headers = await _getAuthHeaders(protected: true);
        headers["Content-Type"] = "application/json"; // Ensure content type is set for DELETE with body
        final url = '$baseUrl/api/invites/decline/$friendshipId';
        final response = await http.post(
         Uri.parse(url),
          headers: headers,
          body: jsonEncode({'friendship_id': friendshipId})
         );

      if (response.statusCode == 200) return true;
      await _handleUnauthorized(response.statusCode);
      return false;
    } catch (e) {
      // Decline invite error: handled by returning false
      return false;
    }
  }
}

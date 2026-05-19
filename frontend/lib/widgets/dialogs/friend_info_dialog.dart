import 'package:flutter/material.dart';
import '../../utils/image_utils.dart';

// A simple dialog to show friend information when a friend marker is tapped on the map.
class FriendInfoDialog {
  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> friendData,
  }) async {
    // the friendData map is expected to contain keys like:
    final String name = friendData['name'] ?? 'Unknown';
    final String email = friendData['email'] ?? '';
    final dynamic avatar = friendData['avatar'];
    final dynamic updatedAt = friendData['updated_at'];
    final double? latitude = friendData['latitude'] as double?;
    final double? longitude = friendData['longitude'] as double?;

    // Helper function to format time 
    String _formatTime(dynamic timeStr) {
      if (timeStr == null) return 'Unknown';
      try {
        final date = DateTime.parse(timeStr.toString()).toLocal();
        return "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
      } catch (_) {
        return 'Unknown';
      }
    }

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        title: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: getAvatarProvider(avatar),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(),
            _buildInfoRow(
              Icons.access_time_rounded,
              'Last seen',
              _formatTime(updatedAt),
            ),
            const SizedBox(height: 10),
            _buildInfoRow(
              Icons.pin_drop_outlined,
              'Location',
              latitude != null && longitude != null
                  ? '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}'
                  : 'Unknown',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Helper to build a info row for last seen and location
  static Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey.shade600),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
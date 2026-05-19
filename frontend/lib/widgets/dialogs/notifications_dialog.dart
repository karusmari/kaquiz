import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/image_utils.dart';

class NotificationsDialog extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onChanged;

  const NotificationsDialog({
    super.key,
    required this.apiService,
    required this.onChanged,
  });

  /// Static shortcut helper method to open the notification layer cleanly.
  static Future<void> show(
    BuildContext context, {
    required ApiService apiService,
    required VoidCallback onChanged,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) =>
          NotificationsDialog(apiService: apiService, onChanged: onChanged),
    );
  }

  @override
  State<NotificationsDialog> createState() => _NotificationsDialogState();
}

class _NotificationsDialogState extends State<NotificationsDialog> {
  late Future<List<dynamic>?> _invitesFuture;

  @override
  void initState() {
    super.initState();
    _refreshInvites();
  }

  /// Triggers a re-fetch of pending friend requests to update the UI state locally.
  void _refreshInvites() {
    setState(() {
      _invitesFuture = widget.apiService.getPendingInvites();
    });
  }

  /// Dynamically computes container constraints based on item counts to prevent overflows.
  double _calculateDialogHeight(int itemCount) {
    const double rowHeight = 85.0;
    const double minHeight = 120.0;
    const double maxHeight = 450.0;
    return (itemCount * rowHeight).clamp(minHeight, maxHeight);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>?>(
      future: _invitesFuture,
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AlertDialog(
            content: SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final invites = snapshot.data ?? [];
        if (invites.isEmpty) {
          return AlertDialog(
            title: const Text('Notifications'),
            content: const Text('No pending friend requests'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        }

        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 8),
          contentPadding: const EdgeInsets.all(8),
          title: const Text('Notifications'),
          content: SizedBox(
            width: double.maxFinite,
            height: _calculateDialogHeight(invites.length),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ListView.builder(
                itemCount: invites.length,
                itemBuilder: (context, index) {
                  return _buildInviteCard(invites[index]);
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// Builds individual interactive transactional cards for each pending user invite.
  Widget _buildInviteCard(Map<String, dynamic> invite) {
    final senderName = invite['sender_name'] ?? 'Unknown';
    final friendshipId = invite['id'] ?? 0;
    final senderAvatar = invite['sender_avatar'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: getAvatarProvider(senderAvatar),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      senderName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'wants to be your friend',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(
                  label: 'Accept',
                  color: const Color(0xFF608962),
                  onPressed: () => _handleInviteAction(
                    friendshipId,
                    senderName,
                    isAccept: true,
                  ),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  label: 'Decline',
                  color: const Color(0xFFE17D75),
                  isOutlined: true,
                  onPressed: () => _handleInviteAction(
                    friendshipId,
                    senderName,
                    isAccept: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Helper factory method to build consistent Action keys across standard UI maps.
  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
    bool isOutlined = false,
  }) {
    final style = ButtonStyle(
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      minimumSize: WidgetStateProperty.all(const Size(120, 32)),
    );

    return SizedBox(
      height: 32,
      child: isOutlined
          ? OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color),
              ).merge(style),
              onPressed: onPressed,
              child: Text(label),
            )
          : ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ).merge(style),
              onPressed: onPressed,
              child: Text(label),
            ),
    );
  }

  /// Processes transaction states over networks asynchronously without dismissing the core parent layer viewport.
  Future<void> _handleInviteAction(
    int friendshipId,
    String senderName, {
    required bool isAccept,
  }) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // doing the network transaction call to accept or decline the invite based on user action
      final success = isAccept
          ? await widget.apiService.acceptInvite(friendshipId)
          : await widget.apiService.declineInvite(friendshipId);

      // in case of success, we show a confirmation snackbar and trigger a local UI refresh to update the pending invites list
      if (success) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              isAccept ? '$senderName added!' : 'Declined $senderName',
            ),
          ),
        );

        // Try refreshing the map; swallow errors to avoid breaking the dialog
        try {
          widget.onChanged();
        } catch (_) {
          // Refresh failed; ignore to keep UI stable
        }

        _refreshInvites();
      }
      // in case of failure
      else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Server returned FALSE (ID: $friendshipId, Action: ${isAccept ? "Accept" : "Decline"})',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (codeCrash) {
      // in case of a crash during the network call, we catch it and show a snackbar with the error details. 
      // This prevents the dialog from crashing and provides feedback to the user.
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Code crash: $codeCrash'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 7),
        ),
      );
    }
  }
}

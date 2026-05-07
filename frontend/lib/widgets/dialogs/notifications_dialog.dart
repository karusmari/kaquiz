import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';

Future<void> showNotificationsDialog(
  BuildContext context,
  ApiService apiService,
  VoidCallback onChanged,
) async {
  double dialogHeightFor(int itemCount) {
    const double rowHeight = 85;
    const double minHeight = 120;
    const double maxHeight = 450;
    return (itemCount * rowHeight).clamp(minHeight, maxHeight).toDouble();
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => FutureBuilder<List<dynamic>?>(
      future: apiService.getPendingInvites(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AlertDialog(content: CircularProgressIndicator());
        }

        final invites = snapshot.data ?? [];
        if (invites.isEmpty) {
          return AlertDialog(
            title: const Text('Notifications'),
            content: const Text('No pending friend requests'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
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
            height: dialogHeightFor(invites.length),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ListView.builder(
                itemCount: invites.length,
                itemBuilder: (c, i) {
                  final invite = invites[i];
                  final senderName = invite['sender_name'] ?? 'Unknown';
                  final friendshipId = invite['id'] ?? 0;

                  ImageProvider? avatarProvider;
                  final senderAvatar = invite['sender_avatar'];
                  if (senderAvatar is String && senderAvatar.isNotEmpty) {
                    if (senderAvatar.startsWith('data:image/')) {
                      final comma = senderAvatar.indexOf(',');
                      if (comma != -1 && comma < senderAvatar.length - 1) {
                        try {
                          final bytes = base64Decode(
                            senderAvatar.substring(comma + 1),
                          );
                          avatarProvider = MemoryImage(bytes);
                        } catch (_) {
                          avatarProvider = NetworkImage(senderAvatar);
                        }
                      } else {
                        avatarProvider = NetworkImage(senderAvatar);
                      }
                    } else {
                      avatarProvider = NetworkImage(senderAvatar);
                    }
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 3,
                      horizontal: 2,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 6,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.grey.shade300,
                                  backgroundImage: avatarProvider,
                                  child: avatarProvider == null
                                      ? const Icon(
                                          Icons.person,
                                          size: 18,
                                          color: Colors.black54,
                                        )
                                      : null,
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
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 32,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(
                                      255,
                                      96,
                                      137,
                                      98,
                                    ),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    minimumSize: const Size(120, 32),
                                  ),
                                  onPressed: () async {
                                    final ok = await apiService.acceptInvite(
                                      friendshipId,
                                    );
                                    if (ok && dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('$senderName added!'),
                                        ),
                                      );
                                      onChanged();
                                    }
                                  },
                                  child: const Text('Accept'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 32,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color.fromARGB(
                                      255,
                                      225,
                                      125,
                                      117,
                                    ),
                                    side: const BorderSide(
                                      color: Color.fromARGB(255, 225, 125, 117),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    minimumSize: const Size(120, 32),
                                  ),
                                  onPressed: () async {
                                    final ok = await apiService.declineInvite(
                                      friendshipId,
                                    );
                                    if (ok && dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Declined $senderName'),
                                        ),
                                      );
                                      onChanged();
                                    } else {
                                      if (dialogContext.mounted)
                                        Navigator.pop(dialogContext);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Failed to decline'),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('Decline'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    ),
  );
}

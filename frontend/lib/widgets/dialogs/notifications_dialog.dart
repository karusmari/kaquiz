import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../compact_list_card.dart';

Future<void> showNotificationsDialog(
  BuildContext context,
  ApiService apiService,
  VoidCallback onChanged,
) async {
  double dialogHeightFor(int itemCount) {
    const double rowHeight = 72;
    const double minHeight = 96;
    const double maxHeight = 360;
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
          title: const Text('Notifications'),
          content: SizedBox(
            width: double.maxFinite,
            height: dialogHeightFor(invites.length),
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

                return CompactListCard(
                  leading: CircleAvatar(
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
                  title: senderName,
                  subtitle: const Text('wants to be your friend'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () async {
                          final ok = await apiService.acceptInvite(
                            friendshipId,
                          );
                          if (ok && dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$senderName added!')),
                            );
                            onChanged();
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () async {
                          final ok = await apiService.declineInvite(
                            friendshipId,
                          );
                          if (ok && dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Declined $senderName')),
                            );
                            onChanged();
                          } else {
                            if (dialogContext.mounted)
                              Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to decline'),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
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

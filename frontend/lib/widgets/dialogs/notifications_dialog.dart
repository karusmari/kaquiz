import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../compact_list_card.dart';

Future<void> showNotificationsDialog(
  BuildContext context,
  ApiService apiService,
  VoidCallback onChanged,
) async {
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
            child: ListView.builder(
              itemCount: invites.length,
              itemBuilder: (c, i) {
                final invite = invites[i];
                final senderName = invite['sender_name'] ?? 'Unknown';
                final friendshipId = invite['id'] ?? 0;

                return CompactListCard(
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
                        onPressed: () {
                          // TODO: Implement decline after backend supports it
                          Navigator.pop(dialogContext);
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

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../compact_list_card.dart';

Future<void> showFriendsListDialog(
  BuildContext context,
  ApiService apiService,
  VoidCallback onChanged,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => FutureBuilder<List<dynamic>?>(
      future: apiService.getFriendsList(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AlertDialog(content: CircularProgressIndicator());
        }

        final friends = snapshot.data ?? [];
        if (friends.isEmpty) {
          return AlertDialog(
            title: const Text('My Friends'),
            content: const Text('No friends yet'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          );
        }

        return AlertDialog(
          title: const Text('My Friends'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: friends.length,
              itemBuilder: (c, i) {
                final friend = friends[i];
                final name = friend['name'] ?? 'Unknown';
                final email = friend['email'] ?? '';
                final id = friend['user_id'] ?? 0;

                return CompactListCard(
                  title: name,
                  subtitle: Text(
                    email,
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: dialogContext,
                        builder: (confirmContext) => AlertDialog(
                          title: const Text('Delete friend'),
                          content: Text('Remove $name from friends?'),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(confirmContext, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () =>
                                  Navigator.pop(confirmContext, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        final ok = await apiService.deleteFriend(id);
                        if (ok) {
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$name deleted')),
                          );
                          onChanged();
                        }
                      }
                    },
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

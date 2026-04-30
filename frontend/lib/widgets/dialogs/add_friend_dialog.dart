import 'package:flutter/material.dart';

import '../../services/api_service.dart';

Future<void> showAddFriendDialog(
  BuildContext context,
  ApiService apiService,
) async {
  final TextEditingController emailController = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Add friend by email'),
      content: TextField(
        controller: emailController,
        decoration: const InputDecoration(hintText: "Friend's email"),
        keyboardType: TextInputType.emailAddress,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final email = emailController.text.trim();
            final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
            if (email.isEmpty || !emailRegex.hasMatch(email)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter a valid email address')),
              );
              return;
            }

            final currentUserId = await apiService.getCurrentUserId();
            final user = await apiService.searchUserByEmail(email);
            if (user == null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('User not found')));
              return;
            }

            final foundId = (user['id'] is int)
                ? user['id'] as int
                : (user['id'] as num).toInt();

            if (currentUserId != null && foundId == currentUserId) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('You cannot add yourself')),
              );
              return;
            }

            final friendsLocations = await apiService.getFriendsLocations();
            if (friendsLocations != null) {
              final alreadyFriend = friendsLocations.any((f) {
                final id = f['user_id'];
                return (id is int && id == foundId) ||
                    (id is num && id.toInt() == foundId);
              });
              if (alreadyFriend) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('This user is already your friend'),
                  ),
                );
                return;
              }
            }

            final confirmed = await showDialog<bool>(
              context: context,
              builder: (confirmContext) => AlertDialog(
                title: const Text('Send friend request'),
                content: Text('Send friend request to ${user['email']}?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(confirmContext, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(confirmContext, true),
                    child: const Text('Send'),
                  ),
                ],
              ),
            );

            if (confirmed != true) return;

            final ok = await apiService.sendInvite(foundId);
            if (!dialogContext.mounted) return;
            Navigator.pop(dialogContext);
            if (ok) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Friend request sent!')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to send friend request')),
              );
            }
          },
          child: const Text('Send'),
        ),
      ],
    ),
  );
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/image_utils.dart'; 

Future<void> showAddFriendDialog(
  BuildContext context,
  ApiService apiService,
) async {
  final TextEditingController searchController = TextEditingController();

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      Timer? _debounce;
      List<dynamic> suggestions = [];
      bool isSearching = false;

      return StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 14),
          contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          title: const Text('Add friend'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    hintText: "Search by name or email",
                    prefixIcon: const Icon(Icons.search),
                    hintStyle: const TextStyle(fontSize: 14),
                  ),
                  onChanged: (value) {
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(const Duration(milliseconds: 300), () async {
                      final q = value.trim();
                      if (q.isEmpty) {
                        setState(() => suggestions = []);
                        return;
                      }
                      setState(() => isSearching = true);
                      final res = await apiService.searchUsers(q);
                      setState(() {
                        suggestions = res ?? [];
                        isSearching = false;
                      });
                    });
                  },
                ),
                const SizedBox(height: 10),
                if (isSearching) const LinearProgressIndicator(),
                // If there are no results and not currently searching, show a small message
                if (!isSearching && suggestions.isEmpty && searchController.text.isNotEmpty)
                   const Padding(
                     padding: EdgeInsets.all(8.0),
                     child: Text("No users found", style: TextStyle(color: Colors.grey)),
                   ),
                if (suggestions.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: suggestions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final user = suggestions[i];
                        final email = user['email'] ?? '';
                        final name = user['name'] ?? email;
                        final foundId = (user['id'] is int) ? user['id'] as int : (user['id'] as num).toInt();

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: getAvatarProvider(user['avatar']),
                            child: user['avatar'] == null ? const Icon(Icons.person) : null,
                          ),
                          title: Text(name),
                          subtitle: Text(email),
                          onTap: () async {
                            // 1. Check if the user is already a friend
                            final friends = await apiService.getFriendsLocations();
                            final isAlreadyFriend = friends?.any((f) => 
                              (f['user_id'] as num).toInt() == foundId) ?? false;

                            if (isAlreadyFriend) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('This user is already your friend')),
                              );
                              return;
                            }

                            // 2. Ask for confirmation
                            if (!context.mounted) return;
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (confirmCtx) => AlertDialog(
                                title: const Text('Send request'),
                                content: Text('Send friend request to $name?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(confirmCtx, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(confirmCtx, true), child: const Text('Send')),
                                ],
                              ),
                            );

                            if (confirmed == true) {
                              final ok = await apiService.sendInvite(foundId);
                              if (dialogContext.mounted) Navigator.pop(dialogContext);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(ok ? 'Request sent!' : 'Failed to send request')),
                                );
                              }
                            }
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
          ],
        ),
      );
    },
  );
}
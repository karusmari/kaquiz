import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../compact_list_card.dart';
import '../../provider/friends_provider.dart';

Future<void> showFriendsListDialog(
  BuildContext context,
  ApiService apiService,
  VoidCallback onChanged,
  Future<void> Function(int friendId) onFriendSelected,
) async {
  double dialogHeightFor(int itemCount) {
    const double rowHeight = 72;
    const double minHeight = 96;
    const double maxHeight = 420;
    return (itemCount * rowHeight).clamp(minHeight, maxHeight).toDouble();
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final friendsModel = Provider.of<FriendsModel>(
        dialogContext,
        listen: false,
      );
      // initiate load (safe to call repeatedly; model guards loading state)
      friendsModel.loadFriends();

      return Consumer<FriendsModel>(
        builder: (ctx, fm, _) {
          if (fm.isLoading) {
            return const AlertDialog(content: CircularProgressIndicator());
          }

          final friends = fm.friends;
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
              height: dialogHeightFor(friends.length),
              child: ListView.builder(
                itemCount: friends.length,
                itemBuilder: (c, i) {
                  final friend = friends[i];
                  final name = friend['name'] ?? 'Unknown';
                  final email = friend['email'] ?? '';
                  final id = friend['user_id'] ?? 0;

                  ImageProvider? avatarProvider;
                  final avatar = friend['avatar'];
                  if (avatar is String && avatar.isNotEmpty) {
                    if (avatar.startsWith('data:image/')) {
                      final comma = avatar.indexOf(',');
                      if (comma != -1 && comma < avatar.length - 1) {
                        try {
                          final bytes = base64Decode(
                            avatar.substring(comma + 1),
                          );
                          avatarProvider = MemoryImage(bytes);
                        } catch (_) {
                          avatarProvider = NetworkImage(avatar);
                        }
                      } else {
                        avatarProvider = NetworkImage(avatar);
                      }
                    } else {
                      avatarProvider = NetworkImage(avatar);
                    }
                  }

                  return CompactListCard(
                    onTap: () async {
                      final parsedId = id is num
                          ? id.toInt()
                          : int.tryParse(id.toString()) ?? 0;
                      await onFriendSelected(parsedId);
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    },
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
                          final ok = await fm.deleteFriend(id);
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
      );
    },
  );
}

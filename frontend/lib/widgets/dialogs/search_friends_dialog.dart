import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../compact_list_card.dart';

Future<void> showSearchFriendsDialog(
  BuildContext context,
  ApiService apiService,
  Future<void> Function(int friendId) onFriendSelected,
) async {
  final TextEditingController searchController = TextEditingController();
  List<dynamic> allFriends = [];
  List<dynamic> filteredFriends = [];

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => FutureBuilder<List<dynamic>?>(
      future: apiService.getFriendsList(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AlertDialog(content: CircularProgressIndicator());
        }

        allFriends = snapshot.data ?? [];
        filteredFriends = allFriends;

        return StatefulBuilder(
          builder: (c, setState) {
            final visibleItems = filteredFriends.isEmpty
                ? 1
                : filteredFriends.length.clamp(1, 6);
            final listHeight = filteredFriends.isEmpty
                ? 72.0
                : visibleItems * 72.0;

            return AlertDialog(
              title: const Text('Search friends'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'Name or email...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (query) {
                        setState(() {
                          if (query.isEmpty) {
                            filteredFriends = allFriends;
                          } else {
                            final lower = query.toLowerCase();
                            filteredFriends = allFriends
                                .where(
                                  (f) =>
                                      (f['name'] as String)
                                          .toLowerCase()
                                          .contains(lower) ||
                                      (f['email'] as String)
                                          .toLowerCase()
                                          .contains(lower),
                                )
                                .toList();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: listHeight,
                      child: filteredFriends.isEmpty
                          ? const Center(child: Text('No friends found'))
                          : ListView.builder(
                              itemCount: filteredFriends.length,
                              itemBuilder: (c, i) {
                                final friend = filteredFriends[i];
                                final name = friend['name'] ?? 'Unknown';
                                final email = friend['email'] ?? '';
                                final friendId =
                                    friend['user_id'] ?? friend['id'] ?? 0;

                                ImageProvider? avatarProvider;
                                final avatar = friend['avatar'];
                                if (avatar is String && avatar.isNotEmpty) {
                                  if (avatar.startsWith('data:image/')) {
                                    final comma = avatar.indexOf(',');
                                    if (comma != -1 &&
                                        comma < avatar.length - 1) {
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
                                    final parsedId = friendId is num
                                        ? friendId.toInt()
                                        : int.tryParse(friendId.toString()) ??
                                              0;
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
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 13,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
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
    ),
  );
}

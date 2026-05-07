import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';

Future<void> showAddFriendDialog(
  BuildContext context,
  ApiService apiService,
) async {
  final TextEditingController emailController = TextEditingController();
  final int? currentUserId = await apiService.getCurrentUserId();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      Timer? _debounce;
      List<dynamic> suggestions = [];
      bool isSearching = false;

      ImageProvider? _avatarProviderFrom(dynamic avatar) {
        if (avatar is String && avatar.isNotEmpty) {
          if (avatar.startsWith('data:image/')) {
            final comma = avatar.indexOf(',');
            if (comma != -1 && comma < avatar.length - 1) {
              try {
                final bytes = base64Decode(avatar.substring(comma + 1));
                return MemoryImage(bytes);
              } catch (_) {
                return NetworkImage(avatar);
              }
            } else {
              return NetworkImage(avatar);
            }
          } else {
            return NetworkImage(avatar);
          }
        }
        return null;
      }

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
                  controller: emailController,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    hintText: "Search by name or email",
                    prefixIcon: const Icon(Icons.search),
                    hintStyle: const TextStyle(fontSize: 14),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (value) {
                    // debounce to avoid spamming the API on every keystroke
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(
                      const Duration(milliseconds: 300),
                      () async {
                        final q = value.trim();
                        if (q.isEmpty) {
                          setState(() {
                            suggestions = [];
                          });
                          return;
                        }
                        setState(() => isSearching = true);
                        final res = await apiService.searchUsers(q);
                        setState(() {
                          suggestions = res ?? [];
                          isSearching = false;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),
                if (isSearching) const LinearProgressIndicator(),
                if (suggestions.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: suggestions.length,
                      separatorBuilder: (_, __) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Divider(
                          height: 8,
                          thickness: 1,
                          color: Colors.grey,
                        ),
                      ),
                      itemBuilder: (ctx, i) {
                        final user = suggestions[i];
                        final email = user['email'] ?? '';
                        final name = user['name'] ?? email;
                        final avatar = _avatarProviderFrom(user['avatar']);
                        final foundId = (user['id'] is int)
                            ? user['id'] as int
                            : (user['id'] as num?)?.toInt() ?? 0;

                        if (currentUserId != null && foundId == currentUserId) {
                          return const SizedBox.shrink();
                        }

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage: avatar,
                            child: avatar == null
                                ? const Icon(
                                    Icons.person,
                                    size: 18,
                                    color: Colors.black54,
                                  )
                                : null,
                          ),
                          title: Text(name),
                          subtitle: Text(email),
                          onTap: () async {
                            final foundId = (user['id'] is int)
                                ? user['id'] as int
                                : (user['id'] as num?)?.toInt() ?? 0;
                            if (currentUserId != null &&
                                foundId == currentUserId) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('You cannot add yourself'),
                                ),
                              );
                              return;
                            }

                            final friendsLocations = await apiService
                                .getFriendsLocations();
                            if (friendsLocations != null) {
                              final alreadyFriend = friendsLocations.any((f) {
                                final id = f['user_id'];
                                return (id is int && id == foundId) ||
                                    (id is num && id.toInt() == foundId);
                              });
                              if (alreadyFriend) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'This user is already your friend',
                                    ),
                                  ),
                                );
                                return;
                              }
                            }

                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (confirmContext) => AlertDialog(
                                title: const Text('Send friend request'),
                                content: Text('Send friend request to $email?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(confirmContext, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(confirmContext, true),
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
                                const SnackBar(
                                  content: Text('Friend request sent!'),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Failed to send friend request',
                                  ),
                                ),
                              );
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
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim();
                final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+ ');
                if (email.isEmpty || !emailRegex.hasMatch(email)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid email address'),
                    ),
                  );
                  return;
                }

                final currentUserId = await apiService.getCurrentUserId();
                final user = await apiService.searchUserByEmail(email);
                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User not found')),
                  );
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
                    const SnackBar(
                      content: Text('Failed to send friend request'),
                    ),
                  );
                }
              },
              child: const Text('Send'),
            ),
          ],
        ),
      );
    },
  );
}

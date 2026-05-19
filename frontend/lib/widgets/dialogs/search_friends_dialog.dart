import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../compact_list_card.dart';
import '../../utils/image_utils.dart';

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
          return const Center(child: CircularProgressIndicator());
        }

        allFriends = snapshot.data ?? [];
        filteredFriends = allFriends;

        return StatefulBuilder(
          builder: (c, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.92,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Search friends',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          hintText: 'Name or email...',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (query) {
                          setState(() {
                            final lower = query.toLowerCase();
                            filteredFriends = allFriends.where((f) {
                              final name = (f['name'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              final email = (f['email'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              return name.contains(lower) ||
                                  email.contains(lower);
                            }).toList();
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.4,
                        ),
                        child: filteredFriends.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(20.0),
                                child: Text('No friends found'),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filteredFriends.length,
                                itemBuilder: (c, i) {
                                  final friend = filteredFriends[i];
                                  final friendId =
                                      friend['user_id'] ?? friend['id'] ?? 0;

                                  return CompactListCard(
                                    onTap: () async {
                                      final parsedId = friendId is num
                                          ? friendId.toInt()
                                          : int.tryParse(friendId.toString()) ??
                                                0;
                                      await onFriendSelected(parsedId);
                                      if (dialogContext.mounted)
                                        Navigator.pop(dialogContext);
                                    },
                                    leading: CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.grey.shade300,
                                      backgroundImage: getAvatarProvider(
                                        friend['avatar'],
                                      ),
                                    ),
                                    title: friend['name'] ?? 'Unknown',
                                    subtitle: Text(
                                      friend['email'] ?? '',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 13,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

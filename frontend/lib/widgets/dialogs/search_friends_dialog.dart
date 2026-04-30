import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../compact_list_card.dart';

Future<void> showSearchFriendsDialog(
  BuildContext context,
  ApiService apiService,
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
          builder: (c, setState) => AlertDialog(
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
                  Expanded(
                    child: filteredFriends.isEmpty
                        ? const Center(child: Text('No friends found'))
                        : ListView.builder(
                            itemCount: filteredFriends.length,
                            itemBuilder: (c, i) {
                              final friend = filteredFriends[i];
                              final name = friend['name'] ?? 'Unknown';
                              final email = friend['email'] ?? '';

                              return CompactListCard(
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
          ),
        );
      },
    ),
  );
}

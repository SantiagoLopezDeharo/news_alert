import 'package:flutter/material.dart';
import 'news_list_item.dart';

class NewsList extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  final void Function(int) onDelete;

  const NewsList({
    super.key,
    required this.messages,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: Text('No FCM messages received yet.'),
      );
    }
    return ListView.separated(
      itemCount: messages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        return NewsListItem(
          msg: messages[i],
          index: i,
          onDelete: onDelete,
        );
      },
    );
  }
}

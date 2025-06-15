import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class NewsListItem extends StatelessWidget {
  final Map<String, dynamic> msg;
  final int index;
  final void Function(int) onDelete;

  const NewsListItem({
    super.key,
    required this.msg,
    required this.index,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const neonAccent = Colors.white;
    const cardBg = Color(0xFF181A20);
    const borderColor = Color(0xFF23272F);
    return Container(
      decoration: BoxDecoration(
        color: cardBg.withOpacity(0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ListTile(
        key: ValueKey(index),
        contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        title: SelectableText(
          msg['title'] ?? 'No Title',
          style: const TextStyle(
            color: neonAccent,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: 0.2,
          ),
        ),
        subtitle: Text(
          msg['link'] ?? '',
          style: TextStyle(color: neonAccent.withOpacity(0.7), fontSize: 14),
        ),
        onTap: () {
          final l = msg['link'];
          if (l != null) launchUrl(Uri.parse(l));
        },
        onLongPress: () => onDelete(index),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          color: neonAccent.withOpacity(0.85),
          onPressed: () => onDelete(index),
          tooltip: 'Delete',
        ),
      ),
    );
  }
}

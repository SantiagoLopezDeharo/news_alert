import 'package:flutter/material.dart';

class SearchKeyDropdown extends StatelessWidget {
  final List<String> searchKeys;
  final String selectedKey;
  final ValueChanged<String?> onChanged;

  const SearchKeyDropdown({
    super.key,
    required this.searchKeys,
    required this.selectedKey,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const neonAccent = Colors.white;
    const cardBg = Color(0xFF181A20);
    return DropdownButton<String>(
      dropdownColor: cardBg,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: neonAccent,
      ),
      value: selectedKey,
      borderRadius: BorderRadius.circular(14),
      underline: Container(),
      items: searchKeys
          .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e, textAlign: TextAlign.center),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

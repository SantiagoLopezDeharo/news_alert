import 'package:flutter/material.dart';

class DeleteHistoryButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String selectedKey;

  const DeleteHistoryButton({
    super.key,
    required this.onPressed,
    required this.selectedKey,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text("Borrar historial: $selectedKey"),
    );
  }
}

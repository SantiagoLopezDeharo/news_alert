import 'package:flutter/material.dart';

class ModifyKeysButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ModifyKeysButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: const Text('Modify'),
    );
  }
}

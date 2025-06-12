import 'package:flutter/material.dart';

class Modifykeys extends StatefulWidget {
  const Modifykeys({super.key, required this.keys});
  final List<String> keys;

  @override
  State<Modifykeys> createState() => _ModifykeysState();
}

class _ModifykeysState extends State<Modifykeys> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modify Keys'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ...[
              for (var key in widget.keys)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    key,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
            ],
            ElevatedButton(
              onPressed: () {
                // Add your logic to modify keys here
              },
              child: const Text('Modify Keys'),
            ),
          ],
        ),
      ),
    );
  }
}
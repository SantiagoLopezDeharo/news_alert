import 'package:flutter/material.dart';

class Modifykeys extends StatefulWidget {
  Modifykeys({super.key, required this.keys});
  List<String> keys;

  @override
  State<Modifykeys> createState() => _ModifykeysState();
}

class _ModifykeysState extends State<Modifykeys> {
  TextEditingController newKeyController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modify Keys'),
      ),
      body: Center(
        child: Column(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.3,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    for (var key in widget.keys)
                      Card(
                        margin: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              key,
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 24),
                            ElevatedButton(
                              onPressed: () {
                                widget.keys.remove(key);
                                setState(() {});
                              },
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: newKeyController,
                      decoration: const InputDecoration(
                        labelText: 'Enter new key',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      if (newKeyController.text.isEmpty ||
                          widget.keys
                              .contains(newKeyController.text.toLowerCase()) ||
                          newKeyController.text.toLowerCase() == 'all') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invalid Key or already exists'),
                          ),
                        );
                        return;
                      }

                      widget.keys = [
                        newKeyController.text.toLowerCase(),
                        ...widget.keys
                      ];
                      newKeyController.clear();

                      setState(() {});
                    },
                    child: const Text('Add Key'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, widget.keys);
              },
              child: const Text('Confirm Changes'),
            ),
            const SizedBox(height: 6),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

// ignore: must_be_immutable
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
    const neonAccent = Color(0xFF00FFC6);
    const cardBg = Color(0xFF181A20);
    const borderColor = Color(0xFF23272F);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modify Keys'),
        elevation: 0,
        backgroundColor: Colors.black,
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 18, left: 0, right: 0),
                child: ListView.builder(
                  itemCount: widget.keys.length,
                  itemBuilder: (context, idx) {
                    final key = widget.keys[idx];
                    return Card(
                      color: cardBg,
                      margin: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: borderColor, width: 1.2),
                      ),
                      elevation: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 8),
                            child: Text(
                              key,
                              style: const TextStyle(
                                fontSize: 17,
                                color: neonAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: neonAccent,
                            tooltip: 'Delete',
                            onPressed: () {
                              setState(() {
                                widget.keys.removeAt(idx);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: MediaQuery.of(context).size.width * 0.1,
            right: MediaQuery.of(context).size.width * 0.1,
            bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            top: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: newKeyController,
                      style: const TextStyle(color: neonAccent),
                      decoration: InputDecoration(
                        labelText: 'Enter new key',
                        labelStyle: const TextStyle(color: neonAccent),
                        filled: true,
                        fillColor: cardBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: neonAccent),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: neonAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                    ),
                    onPressed: () {
                      if (newKeyController.text.isEmpty ||
                          widget.keys.contains(
                              newKeyController.text.toLowerCase()) ||
                          newKeyController.text.toLowerCase() == 'all') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invalid Key or already exists'),
                          ),
                        );
                        return;
                      }
                      setState(() {
                        widget.keys = [
                          newKeyController.text.toLowerCase(),
                          ...widget.keys
                        ];
                        newKeyController.clear();
                      });
                    },
                    child: const Text('Add Key'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: neonAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(context, widget.keys);
                },
                child: const Text('Confirm Changes'),
              ),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: neonAccent,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

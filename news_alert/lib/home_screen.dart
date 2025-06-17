import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:news_alert/modifyKeys.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'widgets/news_list.dart';
import 'widgets/search_key_dropdown.dart';
import 'widgets/modify_keys_button.dart';
import 'widgets/delete_history_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _messagesRender = [];

  List<String>? searchKeys;
  String selectedKey = "All";
  String? user;

  void setupFCM(String token) async {
    final apiUrl = dotenv.env['API_URL'];

    if (apiUrl != null) {
      final url = Uri.parse('$apiUrl/set-token');
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: '{"id":"$user","token": "$token"}',
      );
    }

    await FirebaseMessaging.instance.requestPermission();
  }

  void loadKeys() async {
    final apiUrl = dotenv.env['API_URL'];
    if (apiUrl == null) return;
    final url = Uri.parse('$apiUrl/users?id=$user');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List<String> keys = [];
      keys.add("All");

      if (data["topics"] != null) {
        keys.addAll(List<String>.from(data["topics"]));
      }
      selectedKey = keys.isNotEmpty ? keys[0] : "All";
      setState(() {
        searchKeys = keys;
      });

      FirebaseMessaging messaging = FirebaseMessaging.instance;
      String? token = await messaging.getToken();
      if (token != null && data["token"] != token) {
        setupFCM(token);
      }
    } else if (response.statusCode == 404) {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      String? token = await messaging.getToken();
      if (token == null) return;
      setupFCM(token);

      setState(() {
        searchKeys = ["All"];
        selectedKey = "All";
      });
    } else {
      showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('Error'),
            content: const Text(
              'Failed to load search keys. Is possible that the API is not running or the server crushed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _initUser().then((_) {
      loadKeys();
    });
    WidgetsBinding.instance.addObserver(this);
    _loadStoredMessages();

    FirebaseMessaging.onMessage.listen((msg) => _addMessage(msg));
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _handleLink(msg.data);
    });
    FirebaseMessaging.instance.getInitialMessage().then((msg) {
      if (msg != null) {
        _handleLink(msg.data);
      }
    });
  }

  Future<void> _initUser() async {
    final prefs = await SharedPreferences.getInstance();
    user = prefs.getString('user');
    if (user == null) {
      final random = Random();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      user = 'user_${timestamp}_${random.nextInt(100000)}';
      await prefs.setString('user', user!);
    }

    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _loadStoredMessages();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadStoredMessages() async {
    final db = await DatabaseProvider.instance.database;
    final rows = await db.query('messages', orderBy: 'timestamp DESC');
    setState(() {
      _messages = List<Map<String, dynamic>>.from(rows);
      _messagesRender = _messages
          .where(
            (msg) =>
                selectedKey == "All" ||
                msg['title']?.toLowerCase().contains(selectedKey) == true,
          )
          .toList();
    });
  }

  Future<void> _addMessage(RemoteMessage msg) async {
    if (_messages.any((m) => m["link"] == msg.data['link'])) return;

    final db = await DatabaseProvider.instance.database;
    final ts = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'messages',
      {
        'title': msg.notification?.title,
        'link': msg.data['link'] ?? '',
        'timestamp': ts,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    setState(() {
      _messages.insert(0, {...msg.data, 'title': msg.notification?.title});

      _messagesRender = _messages
          .where(
            (msg) =>
                selectedKey == "All" ||
                msg['title']?.toLowerCase().contains(selectedKey) == true,
          )
          .toList();
    });
  }

  void _handleLink(Map<String, dynamic> data) {
    final link = data['link'];
    if (link != null) launchUrl(Uri.parse(link));
  }

  void delete() async {
    bool? ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text(
          'Are you sure you want to erase saved news alerts?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final db = await DatabaseProvider.instance.database;
    if (selectedKey == "All") {
      await db.delete('messages');
      _messages.clear();
      _messagesRender.clear();
    } else {
      await db.delete("messages",
          where: "title LIKE ?", whereArgs: ["%$selectedKey%"]);
      _messages.removeWhere(
        (msg) => msg['title']?.toLowerCase().contains(selectedKey) == true,
      );
      _messagesRender = _messages
          .where(
            (msg) =>
                selectedKey == "All" ||
                msg['title']?.toLowerCase().contains(selectedKey) == true,
          )
          .toList();
    }
    setState(() {});
  }

  void deleteItem(int index) async {
    bool? ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Are you sure you want to delete this new ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    if (index < 0 || index >= _messagesRender.length) return;

    final db = await DatabaseProvider.instance.database;
    final msg = _messagesRender[index];
    await db.delete(
      'messages',
      where: 'link = ?',
      whereArgs: [msg['link']],
    );
    setState(() {
      _messages.removeWhere((m) => m['link'] == msg['link']);
      _messagesRender.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    const neonAccent = Colors.white;
    const cardBg = Color(0xFF181A20);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'News Alerts',
          style: TextStyle(
            color: neonAccent,
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: 1.2,
            shadows: [
              Shadow(
                blurRadius: 18,
                color: Colors.white.withOpacity(0.9),
                offset: const Offset(0, 0),
              ),
              Shadow(
                blurRadius: 32,
                color: Colors.white.withOpacity(0.5),
                offset: const Offset(0, 0),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                searchKeys != null
                    ? SearchKeyDropdown(
                        searchKeys: searchKeys!,
                        selectedKey: selectedKey,
                        onChanged: (value) {
                          selectedKey = value ?? selectedKey;
                          _messagesRender = _messages
                              .where(
                                (msg) =>
                                    selectedKey == "All" ||
                                    msg['title']?.toLowerCase().contains(
                                              selectedKey,
                                            ) ==
                                        true,
                              )
                              .toList();
                          setState(() {});
                        },
                      )
                    : const CircularProgressIndicator(),
                const SizedBox(width: 10),
                ModifyKeysButton(
                  onPressed: () {
                    final keysWithoutAll =
                        searchKeys!.where((k) => k != "All").toList();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Modifykeys(keys: keysWithoutAll),
                      ),
                    ).then((newkeys) {
                      if (newkeys != null) {
                        final apiUrl = dotenv.env['API_URL'];
                        final url = Uri.parse('$apiUrl/set-topics');
                        http.post(
                          url,
                          headers: {'Content-Type': 'application/json'},
                          body: jsonEncode({"id": user, "topics": newkeys}),
                        );
                        setState(() {
                          searchKeys = ["All", ...newkeys];
                        });
                      }
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            DeleteHistoryButton(
              onPressed: delete,
              selectedKey: selectedKey,
            ),
            const SizedBox(height: 18),
            TextField(
              style: const TextStyle(color: neonAccent),
              decoration: InputDecoration(
                labelText: 'search by title',
                labelStyle: const TextStyle(color: neonAccent),
                filled: true,
                fillColor: cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: neonAccent),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onChanged: (value) {
                if (value.isEmpty) {
                  _messagesRender = _messages
                      .where(
                        (msg) =>
                            selectedKey == "All" ||
                            msg['title']?.toLowerCase().contains(
                                      selectedKey,
                                    ) ==
                                true,
                      )
                      .toList();
                } else {
                  _messagesRender = _messages
                      .where(
                        (msg) =>
                            (selectedKey == "All" ||
                                msg['title']
                                    ?.toLowerCase()
                                    .contains(selectedKey)) &&
                            msg['title']
                                    ?.toLowerCase()
                                    .contains(value.toLowerCase()) ==
                                true,
                      )
                      .toList();
                }
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: NewsList(
                messages: _messagesRender,
                onDelete: deleteItem,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

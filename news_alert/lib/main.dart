import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:news_alert/modifyKeys.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final db = await _DatabaseProvider.instance.database;
  if (message.notification != null) {
    await db.insert(
      'messages',
      {
        'title': message.notification!.title,
        'link': message.data['link'] ?? '',
        'timestamp': DateTime.now().millisecondsSinceEpoch
      },
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await _DatabaseProvider.instance.init();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await dotenv.load();

  runApp(
    const MaterialApp(
      title: 'News Alert',
      home: HomeScreen(),
    ),
  );
}

class _DatabaseProvider {
  _DatabaseProvider._();
  static final instance = _DatabaseProvider._();

  static Database? _db;
  Future<Database> get database async {
    if (_db != null) return _db!;
    await init();
    return _db!;
  }

  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      path.join(dbPath, 'news_alert.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            link TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

void setupFCM() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  String? token = await messaging.getToken();

  final apiUrl = dotenv.env['API_URL'];

  if (token != null && apiUrl != null) {
    final url = Uri.parse('$apiUrl/update-token');
    await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: '{"token": "$token"}',
    );
  }

  await FirebaseMessaging.instance.requestPermission();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _messagesRender = [];

  List<String>? searchKeys;
  String selectedKey = "All";

  void loadKeys() async {
    final apiUrl = dotenv.env['API_URL'];
    if (apiUrl == null) return;
    final url = Uri.parse('$apiUrl/get-list');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = response.body;
      List<String> keys = [];
      keys.add("All");

      keys.addAll(
        List<String>.from(
          jsonDecode(data),
        ),
      );
      selectedKey = keys.isNotEmpty ? keys[0] : "All";
      setState(() {
        searchKeys = keys;
      });
    } else {
      showDialog(
          context: context,
          builder: (_) {
            return AlertDialog(
              title: const Text('Error'),
              content: const Text(
                  'Failed to load search keys. Is possible that the API is not running or the server crushed.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          });
    }
  }

  @override
  void initState() {
    super.initState();
    loadKeys();
    setupFCM();

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
    final db = await _DatabaseProvider.instance.database;
    final rows = await db.query(
      'messages',
      orderBy: 'timestamp DESC',
    );
    setState(() {
      _messages = List<Map<String, dynamic>>.from(rows);
      _messagesRender = _messages
          .where((msg) =>
              selectedKey == "All" ||
              msg['title']?.toLowerCase().contains(selectedKey) == true)
          .toList();
    });
  }

  Future<void> _addMessage(RemoteMessage msg) async {
    final db = await _DatabaseProvider.instance.database;
    final ts = DateTime.now().millisecondsSinceEpoch;
    await db.insert('messages', {
      'title': msg.notification?.title,
      'link': msg.data['link'] ?? '',
      'timestamp': ts
    });
    setState(() {
      _messages.insert(
        0,
        {
          ...msg.data,
          'title': msg.notification?.title,
        },
      );

      _messagesRender = _messages
          .where((msg) =>
              selectedKey == "All" ||
              msg['title']?.toLowerCase().contains(selectedKey) == true)
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
        content:
            const Text('Are you sure you want to erase saved news alerts?'),
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
    final db = await _DatabaseProvider.instance.database;
    await db.delete('messages');
    setState(() => _messages.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('News Alerts')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                searchKeys != null
                    ? DropdownButton<String>(
                        dropdownColor: const Color.fromARGB(255, 196, 196, 196),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        value: selectedKey,
                        items: searchKeys!
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    e,
                                    textAlign: TextAlign.center,
                                  ),
                                ))
                            .toList(),
                        onChanged: (value) {
                          selectedKey = value ?? selectedKey;
                          _messagesRender = _messages
                              .where(
                                (msg) =>
                                    selectedKey == "All" ||
                                    msg['title']
                                            ?.toLowerCase()
                                            .contains(selectedKey) ==
                                        true,
                              )
                              .toList();
                          setState(() {});
                        },
                      )
                    : const CircularProgressIndicator(),
                const SizedBox(width: 8),
                ElevatedButton(
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

                        final url = Uri.parse('$apiUrl/update-list');
                        http.post(
                          url,
                          headers: {'Content-Type': 'application/json'},
                          body: jsonEncode(newkeys),
                        );

                        setState(() {
                          searchKeys = ["All", ...newkeys];
                        });
                      }
                    });
                  },
                  child: const Text('Modify'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: delete, child: const Text("Borrar historial")),
            const SizedBox(height: 12),
            Expanded(
              child: _messagesRender.isEmpty
                  ? const Center(child: Text('No FCM messages received yet.'))
                  : ListView.builder(
                      itemCount: _messagesRender.length,
                      itemBuilder: (_, i) {
                        final msg = _messagesRender[i];
                        return Card(
                          child: ListTile(
                            key: ValueKey(i),
                            title: SelectableText(msg['title'] ?? 'No Title'),
                            subtitle: Text(msg['link'] ?? ''),
                            onTap: () {
                              final l = msg['link'];
                              if (l != null) launchUrl(Uri.parse(l));
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

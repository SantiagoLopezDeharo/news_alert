import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final db = await _DatabaseProvider.instance.database;
  await db.insert(
    'messages',
    {'data': jsonEncode(message.data), 'timestamp': DateTime.now().millisecondsSinceEpoch},
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await _DatabaseProvider.instance.init();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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
            data TEXT NOT NULL,
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStoredMessages();

    FirebaseMessaging.onMessage.listen((msg) => _addMessage(msg.data));
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
      _messages = rows
          .map((row) => jsonDecode(row['data'] as String) as Map<String, dynamic>)
          .toList();
    });
  }

  Future<void> _addMessage(Map<String, dynamic> data) async {
    final db = await _DatabaseProvider.instance.database;
    final ts = DateTime.now().millisecondsSinceEpoch;
    await db.insert('messages', {'data': jsonEncode(data), 'timestamp': ts});
    setState(() {
      _messages.insert(0, data);
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
            ElevatedButton(onPressed: delete, child: const Text("Borrar historial")),
            const SizedBox(height: 12),
            Expanded(
              child: _messages.isEmpty
                  ? const Center(child: Text('No FCM messages received yet.'))
                  : ListView.builder(
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final msg = _messages[i];
                        return Card(
                          child: ListTile(
                            key: ValueKey(i),
                            title: Text('Message ${i + 1}'),
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

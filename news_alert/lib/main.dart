import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:news_alert/modifyKeys.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await _DatabaseProvider.instance.init();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await dotenv.load();

  runApp(const NewsAlertApp());
}

class NewsAlertApp extends StatelessWidget {
  const NewsAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color neonAccent = Color(0xFF00FFC6); // Softer neon
    const Color darkBg = Colors.black;
    const Color cardBg = Color(0xFF181A20);
    const Color borderColor = Color(0xFF23272F);
    return MaterialApp(
      title: 'News Alert',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: darkBg,
          foregroundColor: neonAccent,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Color(0xFF00FFC6),
            fontWeight: FontWeight.w700,
            fontSize: 22,
            letterSpacing: 1.1,
          ),
        ),
        cardColor: cardBg,
        cardTheme: CardTheme(
          color: cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: borderColor, width: 1.2),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: neonAccent,
            foregroundColor: darkBg,
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          menuStyle: MenuStyle(
            backgroundColor: WidgetStateProperty.all(cardBg),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cardBg,
          labelStyle: const TextStyle(color: neonAccent),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: neonAccent),
          ),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white, fontSize: 16),
          bodyLarge: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: Color(0xFF00FFC6), fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: neonAccent, size: 22),
        dividerColor: borderColor,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
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
            link TEXT NOT NULL UNIQUE,
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
        // ignore: use_build_context_synchronously
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
      user = 'user_${timestamp}_${random.nextInt(100000)}';
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
    final db = await _DatabaseProvider.instance.database;
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

    final db = await _DatabaseProvider.instance.database;
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
    final db = await _DatabaseProvider.instance.database;
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

    final db = await _DatabaseProvider.instance.database;
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
    const borderColor = Color(0xFF23272F);
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
                    ? DropdownButton<String>(
                        dropdownColor: cardBg,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: neonAccent,
                        ),
                        value: selectedKey,
                        borderRadius: BorderRadius.circular(14),
                        underline: Container(),
                        items: searchKeys!
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(e, textAlign: TextAlign.center),
                              ),
                            )
                            .toList(),
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
                  child: const Text('Modify'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: delete,
              child: Text("Borrar historial: $selectedKey"),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: _messagesRender.isEmpty
                  ? const Center(
                      child: Text('No FCM messages received yet.'),
                    )
                  : ListView.separated(
                      itemCount: _messagesRender.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final msg = _messagesRender[i];
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
                            key: ValueKey(i),
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
                            onLongPress: () => deleteItem(i),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: neonAccent.withOpacity(0.85),
                              onPressed: () => deleteItem(i),
                              tooltip: 'Delete',
                            ),
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

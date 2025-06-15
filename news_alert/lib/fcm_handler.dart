import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'database_provider.dart';
import 'package:sqflite/sqflite.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final db = await DatabaseProvider.instance.database;
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

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

class DatabaseProvider {
  DatabaseProvider._();
  static final instance = DatabaseProvider._();

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

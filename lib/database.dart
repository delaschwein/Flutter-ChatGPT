import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'chat.dart';
import 'message.dart';

class DatabaseProvider {
  static const String CHAT_TABLE = "chat";
  static const String MESSAGE_TABLE = "message";

  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'chat_app_database.db');

    return await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''
          CREATE TABLE $CHAT_TABLE (
            id TEXT PRIMARY KEY,
            createdAt STRING
          )
        ''');

      await db.execute('''
          CREATE TABLE $MESSAGE_TABLE (
            id TEXT PRIMARY KEY,
            chatId TEXT,
            sender TEXT,
            content TEXT,
            createdAt INTEGER,
            messageType TEXT,
            FOREIGN KEY (chatId) REFERENCES $CHAT_TABLE(id) ON DELETE CASCADE
          )
        ''');
    });
  }

  static Future<List<Chat>> getChats() async {
    final db = await database;
    final chats = await db.query(CHAT_TABLE, orderBy: "createdAt DESC");

    return chats.map((chat) => Chat.fromMap(chat)).toList();
  }

  static Future<void> deleteChat(String id) async {
    final db = await database;
    await db.delete(CHAT_TABLE, where: "id = ?", whereArgs: [id]);
  }

  static Future<void> addChat(Chat chat) async {
    final db = await database;
    await db.insert(CHAT_TABLE, chat.toMap());
  }

  static Future<void> addMessage(Message message) async {
    final db = await database;
    await db.insert(MESSAGE_TABLE, message.toMap());
  }

  static Future<List<Message>> getMessages(String chatId) async {
    final db = await database;
    final messages = await db.query(MESSAGE_TABLE,
        where: "chatId = ?", whereArgs: [chatId], orderBy: "createdAt ASC");

    return messages.map((message) => Message.fromMap(message)).toList();
  }
}

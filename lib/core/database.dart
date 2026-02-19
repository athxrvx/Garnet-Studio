import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Initialize FFI for Windows/Linux/macOS
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'garnet_studio.db');

    return await openDatabase(
      path,
      version: 6, // Bumped to force migration/check
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // ... previous migrations ...
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE models (
          name TEXT PRIMARY KEY,
          size INTEGER,
          installed_at TEXT,
          is_active INTEGER DEFAULT 0,
          temperature REAL DEFAULT 0.7,
          top_p REAL DEFAULT 0.9,
          top_k INTEGER DEFAULT 40,
          context_length INTEGER DEFAULT 2048,
          system_prompt TEXT,
          max_tokens INTEGER DEFAULT -1
        )
      ''');
    }
    // Fix for missing tables in v3-v5 due to initial onCreate error
    if (oldVersion < 3 || oldVersion <= 5) {
       // Check if workspace table exists, if not create it
       final check = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='workspaces'");
       if (check.isEmpty) {
          // Research Engine Tables
          await db.execute('''
            CREATE TABLE workspaces (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
          
          await db.execute('''
            CREATE TABLE documents (
              id TEXT PRIMARY KEY,
              workspace_id TEXT NOT NULL,
              name TEXT NOT NULL,
              uploaded_at TEXT NOT NULL,
              chunk_count INTEGER DEFAULT 0,
              processing_status TEXT DEFAULT 'processed',
              FOREIGN KEY (workspace_id) REFERENCES workspaces (id) ON DELETE CASCADE
            )
          ''');
          
          await db.execute('''
            CREATE TABLE chunks (
              id TEXT PRIMARY KEY,
              document_id TEXT NOT NULL,
              workspace_id TEXT NOT NULL,
              content TEXT NOT NULL,
              embedding TEXT, 
              chunk_index INTEGER,
              FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
            )
          ''');
       }
    }
    
    if (oldVersion < 4) {
      // Initial authorized_devices table was created here in previous versions
      // Or we can just ensure it exists if it wasn't there
      await db.execute('''
        CREATE TABLE IF NOT EXISTS authorized_devices (
          id TEXT PRIMARY KEY,
          device_name TEXT NOT NULL,
          token_hash TEXT NOT NULL,
          last_active TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      // Version 5: Add encryption_key to authorized_devices
      try {
        await db.execute('ALTER TABLE authorized_devices ADD COLUMN encryption_key TEXT');
      } catch (e) {
        // Ignore column already exists error (can happen during development)
        print('Migration error (likely safe): $e');
      }
    }
    
    // Ensure Research Engine tables exist for all versions <= 5 (catch-up for failed onCreate or migrations)
    if (oldVersion <= 5) {
       final check = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='workspaces'");
       if (check.isEmpty) {
          await db.execute('''
            CREATE TABLE workspaces (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
          
          await db.execute('''
            CREATE TABLE documents (
              id TEXT PRIMARY KEY,
              workspace_id TEXT NOT NULL,
              name TEXT NOT NULL,
              uploaded_at TEXT NOT NULL,
              chunk_count INTEGER DEFAULT 0,
              processing_status TEXT DEFAULT 'processed',
              FOREIGN KEY (workspace_id) REFERENCES workspaces (id) ON DELETE CASCADE
            )
          ''');
          
          await db.execute('''
            CREATE TABLE chunks (
              id TEXT PRIMARY KEY,
              document_id TEXT NOT NULL,
              workspace_id TEXT NOT NULL,
              content TEXT NOT NULL,
              embedding TEXT, 
              chunk_index INTEGER,
              FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
            )
          ''');
       }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Authorized Devices Table (V5 Schema)
    await db.execute('''
      CREATE TABLE authorized_devices (
        id TEXT PRIMARY KEY,
        device_name TEXT NOT NULL,
        token_hash TEXT NOT NULL,
        encryption_key TEXT, 
        last_active TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Settings Table
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    
    // Insert default settings
    await db.insert('settings', {'key': 'research_enabled', 'value': 'false'});
    await db.insert('settings', {'key': 'active_model', 'value': ''});
    await db.insert('settings', {'key': 'web_search_enabled', 'value': 'false'});

    // Models Configuration Table
    await db.execute('''
      CREATE TABLE models (
        name TEXT PRIMARY KEY,
        size INTEGER,
        installed_at TEXT,
        is_active INTEGER DEFAULT 0,
        temperature REAL DEFAULT 0.7,
        top_p REAL DEFAULT 0.9,
        top_k INTEGER DEFAULT 40,
        context_length INTEGER DEFAULT 2048,
        system_prompt TEXT,
        max_tokens INTEGER DEFAULT -1
      )
    ''');

    // Research Engine Tables
    await db.execute('''
      CREATE TABLE workspaces (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE documents (
        id TEXT PRIMARY KEY,
        workspace_id TEXT NOT NULL,
        name TEXT NOT NULL,
        uploaded_at TEXT NOT NULL,
        chunk_count INTEGER DEFAULT 0,
        processing_status TEXT DEFAULT 'processed',
        FOREIGN KEY (workspace_id) REFERENCES workspaces (id) ON DELETE CASCADE
      )
    ''');
    
    await db.execute('''
      CREATE TABLE chunks (
        id TEXT PRIMARY KEY,
        document_id TEXT NOT NULL,
        workspace_id TEXT NOT NULL,
        content TEXT NOT NULL,
        embedding TEXT, 
        chunk_index INTEGER,
        FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
      )
    ''');
  }
}

import Foundation

/// Creates and migrates the vault SQLite schema.
enum VaultSchema {
    static let currentVersion = 1

    static func create(in db: SQLiteDatabase) throws {
        try db.execute("""
            CREATE TABLE IF NOT EXISTS entries (
                id          TEXT PRIMARY KEY,
                parent_id   TEXT,
                is_dir      INTEGER NOT NULL DEFAULT 0,
                name        TEXT NOT NULL,
                path        TEXT NOT NULL DEFAULT '',
                type_code   TEXT,
                creator_code TEXT,
                finder_flags INTEGER DEFAULT 0,
                label_color INTEGER DEFAULT 0,
                created_at  TEXT,
                modified_at TEXT,
                data_size   INTEGER DEFAULT 0,
                rsrc_size   INTEGER DEFAULT 0,
                data_sha256 TEXT,
                rsrc_sha256 TEXT,
                encoding    TEXT DEFAULT 'MacRoman',
                source      TEXT,
                added_at    TEXT NOT NULL,
                FOREIGN KEY (parent_id) REFERENCES entries(id) ON DELETE CASCADE
            )
        """)

        try db.execute("""
            CREATE INDEX IF NOT EXISTS idx_parent ON entries(parent_id)
        """)

        try db.execute("""
            CREATE INDEX IF NOT EXISTS idx_name ON entries(name)
        """)

        try db.execute("""
            CREATE INDEX IF NOT EXISTS idx_type ON entries(type_code)
        """)

        try db.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS entries_fts
            USING fts5(entry_id, name, path, source)
        """)

        try db.execute("""
            CREATE TABLE IF NOT EXISTS vault_meta (
                key   TEXT PRIMARY KEY,
                value TEXT
            )
        """)

        try db.execute(
            "INSERT OR IGNORE INTO vault_meta (key, value) VALUES (?, ?)",
            params: ["schema_version", String(currentVersion)]
        )
    }
}

-- =============================================================================
-- Net Web Lab: skema awal database "netlab"
-- Dijalankan otomatis oleh image postgres HANYA SEKALI, yaitu saat volume data
-- masih kosong. Untuk mengulang dari awal: docker compose down -v
-- =============================================================================

CREATE TABLE IF NOT EXISTS notes (
    id         SERIAL PRIMARY KEY,
    text       TEXT        NOT NULL CHECK (char_length(text) BETWEEN 1 AND 280),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO notes (text) VALUES
    ('Halo! Tiga catatan ini dibuat oleh db/init.sql saat database pertama kali dibuat.'),
    ('Alur request: browser -> nginx (web) -> Node.js (api) -> PostgreSQL (db).'),
    ('Tambahkan catatan lewat form di halaman ini atau dengan curl -X POST ke /api/notes.');

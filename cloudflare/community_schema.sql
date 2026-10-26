-- =====================================================================
-- Cloudflare D1: Tabelas da Comunidade KeryxApp (Estilo Instagram / Feed)
-- Execute no painel Cloudflare D1 ou via:
-- npx wrangler d1 execute DB_BIBLIA --file=cloudflare/community_schema.sql
-- =====================================================================

-- 1. Postagens da Comunidade
CREATE TABLE IF NOT EXISTS community_posts (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  user_name TEXT NOT NULL,
  user_avatar TEXT,
  user_badge TEXT DEFAULT 'Membro',
  media_url TEXT,
  media_type TEXT CHECK(media_type IN ('verse_card', 'image', 'video')) DEFAULT 'verse_card',
  caption TEXT,
  bible_reference TEXT,
  bible_version TEXT DEFAULT 'ACF',
  bible_text TEXT,
  card_theme TEXT DEFAULT 'gold',
  praying_count INTEGER DEFAULT 0,
  amen_count INTEGER DEFAULT 0,
  comments_count INTEGER DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 2. Reações (🙏 Orando / ❤️ Amém)
CREATE TABLE IF NOT EXISTS community_reactions (
  post_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  reaction_type TEXT CHECK(reaction_type IN ('pray', 'amen')),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (post_id, user_id, reaction_type),
  FOREIGN KEY (post_id) REFERENCES community_posts(id) ON DELETE CASCADE
);

-- 3. Comentários
CREATE TABLE IF NOT EXISTS community_comments (
  id TEXT PRIMARY KEY,
  post_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  user_name TEXT NOT NULL,
  user_avatar TEXT,
  text TEXT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (post_id) REFERENCES community_posts(id) ON DELETE CASCADE
);

-- 4. Stories Bíblicos do Dia
CREATE TABLE IF NOT EXISTS community_stories (
  id TEXT PRIMARY KEY,
  author_name TEXT NOT NULL,
  author_avatar TEXT,
  title TEXT NOT NULL,
  bible_reference TEXT,
  verse_text TEXT,
  media_url TEXT,
  background_style TEXT DEFAULT 'gold_gradient',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  expires_at DATETIME
);

-- Índices de Alta Performance
CREATE INDEX IF NOT EXISTS idx_posts_created ON community_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_comments_post ON community_comments(post_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_reactions_post ON community_reactions(post_id);

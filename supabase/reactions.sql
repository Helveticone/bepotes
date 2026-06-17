-- ============================================================
--  JURAPOTES — Réactions multiples sur les publications
--  À exécuter dans Supabase > SQL Editor (après TOUT-LE-SQL.sql).
--  Sûr à ré-exécuter (idempotent).
--  On réutilise la table likes (clé (post_id, user_id) = 1 réaction
--  par personne) en ajoutant un TYPE de réaction.
--  Types : 'like' 👍 · 'love' ❤️ · 'haha' 😆 · 'wow' 😮 · 'sad' 😢
--  Les "j'aime" existants deviennent type='like' (valeur par défaut).
-- ============================================================
alter table public.likes add column if not exists type text default 'like';

-- (Aucune nouvelle policy : les réactions suivent les règles de likes.)

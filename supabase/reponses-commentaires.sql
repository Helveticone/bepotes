-- ============================================================
--  BEPOTES — Réponses aux commentaires (fils, 1 niveau)
--  À exécuter dans Supabase > SQL Editor (après TOUT-LE-SQL.sql).
--  Sûr à ré-exécuter (idempotent).
--  Une réponse est un commentaire avec parent_id = commentaire parent.
-- ============================================================
alter table public.comments
  add column if not exists parent_id uuid references public.comments(id) on delete cascade;
create index if not exists comments_parent_idx on public.comments(parent_id);

-- (Aucune nouvelle policy : les réponses suivent les règles des commentaires.)

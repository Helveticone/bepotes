-- ============================================================
--  BEPOTES — Édition des publications et commentaires
--  À exécuter dans Supabase > SQL Editor (après TOUT-LE-SQL.sql).
--  Sûr à ré-exécuter (idempotent).
--  Les posts ont déjà une policy UPDATE (auteur). Les commentaires
--  n'en avaient pas : on l'ajoute pour permettre la modification.
-- ============================================================
drop policy if exists "modifier ses commentaires" on public.comments;
create policy "modifier ses commentaires" on public.comments for update
  using ( auth.uid() = author_id );

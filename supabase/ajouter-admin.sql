-- ============================================================
--  49. AJOUT D'ADMINISTRATEUR / DE MEMBRE par un gestionnaire
--  Un owner/admin peut ajouter une personne (membre ou admin) à son
--  groupe/page, en plus du « rejoindre » classique (auth.uid()=user_id).
--  La promotion d'un membre existant en admin passe, elle, par la
--  policy UPDATE « managers gerent les membres » (déjà en place).
-- ============================================================
drop policy if exists "gestionnaire ajoute un membre" on public.group_members;
create policy "gestionnaire ajoute un membre" on public.group_members for insert
  with check ( public.is_group_manager(group_id) and role in ('member','admin') );
notify pgrst, 'reload schema';

-- ============================================================
--  JURAPOTES — Politiques de Storage (images)
--  À exécuter APRÈS avoir créé les 3 buckets dans
--  Supabase > Storage : "avatars", "covers", "posts"
--  (cocher "Public bucket" à la création des trois).
--
--  Ces règles autorisent :
--   - la LECTURE publique des images (pour les afficher) ;
--   - l'ENVOI / MODIFICATION / SUPPRESSION uniquement par le
--     propriétaire, dans son propre dossier (préfixe = son id).
--  Le moteur enregistre chaque image sous : {user_id}/{timestamp}.jpg
-- ============================================================

-- Lecture publique des 3 buckets
create policy "lecture publique images"
  on storage.objects for select
  using ( bucket_id in ('avatars','covers','posts') );

-- Envoi : seulement dans son propre dossier (1er segment = son uid)
create policy "envoi dans son dossier"
  on storage.objects for insert
  with check (
    bucket_id in ('avatars','covers','posts')
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- Mise à jour (upsert) de ses propres fichiers
create policy "modifier ses images"
  on storage.objects for update
  using (
    bucket_id in ('avatars','covers','posts')
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- Suppression de ses propres fichiers
create policy "supprimer ses images"
  on storage.objects for delete
  using (
    bucket_id in ('avatars','covers','posts')
    and auth.uid()::text = (storage.foldername(name))[1]
  );

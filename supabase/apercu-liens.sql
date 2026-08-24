-- ============================================================
--  BEPOTES — Aperçu de liens (Open Graph) sur les publications
--  À exécuter dans Supabase > SQL Editor. Idempotent.
--  ------------------------------------------------------------
--  Quand un post contient une URL, on stocke l'aperçu (titre, desc,
--  image, site) directement sur le post — récupéré une seule fois à
--  la publication par l'Edge Function « og-preview » (CORS).
--  Voir supabase/apercu-liens-GUIDE.md.
-- ============================================================
alter table public.posts add column if not exists link_url   text;
alter table public.posts add column if not exists link_title text;
alter table public.posts add column if not exists link_desc  text;
alter table public.posts add column if not exists link_image text;
alter table public.posts add column if not exists link_site  text;

-- ============================================================
--  DEVENIR ADMINISTRATEUR (à lancer dans Supabase > SQL Editor)
--  ------------------------------------------------------------
--  Donne les droits admin à TON compte. Indispensable pour
--  accéder au tableau de bord (panneau-hcm-7x2k9.html) et à la
--  régie publicitaire (regie-hcm-7x2k9.html).
--
--  ⚠️ Remplace l'e-mail ci-dessous si tu utilises un autre compte.
--  Tu dois t'être déjà inscrit sur Jurapotes avec cet e-mail.
-- ============================================================
update public.profiles set is_admin = true
where id = (select id from auth.users where email = 'office@helveticonemedia.ch');

-- Vérifie le résultat (doit afficher ton profil avec is_admin = true) :
select p.id, u.email, p.name, p.is_admin
from public.profiles p
join auth.users u on u.id = p.id
where u.email = 'office@helveticonemedia.ch';

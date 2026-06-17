-- ============================================================
--  DEVENIR ADMINISTRATEUR (à lancer dans Supabase > SQL Editor)
--  ------------------------------------------------------------
--  Donne les droits admin à TON compte. Indispensable pour
--  accéder à la Modération (admin.html) et à la Régie pub
--  (admin-pub.html).
--
--  ⚠️ Remplace l'e-mail ci-dessous si tu utilises un autre compte.
--  Tu dois t'être déjà inscrit sur Jurapotes avec cet e-mail.
-- ============================================================
update public.profiles set is_admin = true
where id = (select id from auth.users where email = 'connect41swiss1@gmail.com');

-- Vérifie le résultat (doit afficher ton profil avec is_admin = true) :
select p.id, u.email, p.name, p.is_admin
from public.profiles p
join auth.users u on u.id = p.id
where u.email = 'connect41swiss1@gmail.com';

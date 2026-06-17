-- ============================================================
--  DEVENIR ADMINISTRATEUR (à lancer dans Supabase > SQL Editor)
--  ------------------------------------------------------------
--  Donne les droits admin à TON compte. Indispensable pour
--  accéder au tableau de bord (panneau-hcm-7x2k9.html) et à la
--  régie publicitaire (regie-hcm-7x2k9.html).
--
--  ⚠️ Pré-requis : la colonne profiles.is_admin doit exister
--     (TOUT-LE-SQL.sql section 6). Et tu dois t'être déjà inscrit
--     sur Jurapotes avec cet e-mail.
--  ⚠️ Remplace l'e-mail si tu utilises un autre compte.
-- ============================================================

-- 1) DIAGNOSTIC — le compte existe-t-il ? a-t-il un profil ? is_admin ?
--    (Lance d'abord cette requête seule pour comprendre la situation.)
select u.id as user_id, u.email, u.email_confirmed_at,
       p.id as profile_id, p.name, p.is_admin
from auth.users u
left join public.profiles p on p.id = u.id
where u.email = 'office@helveticonemedia.ch';
--    - 0 ligne            -> ce compte n'existe PAS : inscris-toi d'abord sur le site.
--    - profile_id = null  -> profil manquant : l'étape 2 le crée.
--    - is_admin = true    -> tu es déjà admin : il suffit de te DÉCONNECTER /
--                            RECONNECTER sur le site (le flag est lu à la connexion).


-- 2) DEVENIR ADMIN — crée le profil s'il manque, sinon active is_admin.
insert into public.profiles (id, name, town, is_admin)
select u.id,
       coalesce(nullif(u.raw_user_meta_data->>'name',''), 'Admin'),
       nullif(u.raw_user_meta_data->>'town',''),
       true
from auth.users u
where u.email = 'office@helveticonemedia.ch'
on conflict (id) do update set is_admin = true;


-- 3) VÉRIFICATION — doit afficher ton profil avec is_admin = true.
select p.id, u.email, p.name, p.is_admin
from public.profiles p
join auth.users u on u.id = p.id
where u.email = 'office@helveticonemedia.ch';

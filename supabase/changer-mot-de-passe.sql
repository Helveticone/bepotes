-- ============================================================
--  CHANGER LE MOT DE PASSE D'UN COMPTE (Supabase > SQL Editor)
--  ------------------------------------------------------------
--  Utile si l'interface Authentication ne le permet pas.
--  Le mot de passe est stocké HACHÉ (bcrypt) : on le hache donc
--  avec crypt()/gen_salt() (extension pgcrypto, fournie par Supabase).
--
--  ⚠️ Remplace :
--     - 'MON-NOUVEAU-MOT-DE-PASSE'  par le mot de passe voulu (min. 6 car.)
--     - l'e-mail si besoin
--  Ne partage JAMAIS ce mot de passe en clair ; change-le après coup
--  via Paramètres si tu préfères.
-- ============================================================
update auth.users
set encrypted_password = extensions.crypt('MON-NOUVEAU-MOT-DE-PASSE', extensions.gen_salt('bf')),
    updated_at = now()
where email = 'office@helveticonemedia.ch';

-- (Optionnel) S'assurer que l'e-mail est confirmé, sinon la connexion
-- peut être bloquée selon tes réglages d'authentification :
update auth.users
set email_confirmed_at = coalesce(email_confirmed_at, now())
where email = 'office@helveticonemedia.ch';

-- Vérifie que le compte existe bien (1 ligne attendue) :
select id, email, email_confirmed_at, updated_at
from auth.users
where email = 'office@helveticonemedia.ch';

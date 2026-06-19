-- ============================================================
--  JURAPOTES — TOUT LE SQL À JOUR (à coller d'un bloc)
--  ------------------------------------------------------------
--  Ce fichier regroupe, dans le bon ordre, toutes les évolutions
--  depuis le schéma de base. Il est SÛR à ré-exécuter : tout est
--  en "if exists / if not exists", donc relancer ne casse rien,
--  même si tu as déjà passé certains morceaux.
--
--  À lancer dans : Supabase > SQL Editor > New query > Run
--  (NE PAS rejouer schema.sql : il est déjà en place.)
-- ============================================================


-- ============================================================
--  1. AMITIÉS (table + sécurité + notifications)
-- ============================================================
create table if not exists public.friendships (
  id           uuid primary key default gen_random_uuid(),
  requester_id uuid references public.profiles(id) on delete cascade not null,
  addressee_id uuid references public.profiles(id) on delete cascade not null,
  status       text default 'pending',
  created_at   timestamptz default now(),
  unique (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);

create index if not exists friendships_addressee_idx on public.friendships(addressee_id, status);
create index if not exists friendships_requester_idx on public.friendships(requester_id, status);

alter table public.friendships enable row level security;

drop policy if exists "voir mes amitiés" on public.friendships;
create policy "voir mes amitiés" on public.friendships for select
  using ( auth.uid() = requester_id or auth.uid() = addressee_id );

drop policy if exists "envoyer une demande d'ami" on public.friendships;
drop policy if exists "envoyer une demande" on public.friendships;
create policy "envoyer une demande" on public.friendships for insert
  with check ( auth.uid() = requester_id );

drop policy if exists "répondre à une demande d'ami" on public.friendships;
drop policy if exists "répondre à une demande" on public.friendships;
create policy "répondre à une demande" on public.friendships for update
  using ( auth.uid() = addressee_id or auth.uid() = requester_id );

drop policy if exists "supprimer une amitié" on public.friendships;
create policy "supprimer une amitié" on public.friendships for delete
  using ( auth.uid() = requester_id or auth.uid() = addressee_id );

create or replace function public.notify_on_friendship()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (TG_OP = 'INSERT') then
    insert into public.notifications (user_id, actor_id, type)
    values (new.addressee_id, new.requester_id, 'friend_request');
  elsif (TG_OP = 'UPDATE' and new.status = 'accepted' and old.status = 'pending') then
    insert into public.notifications (user_id, actor_id, type)
    values (new.requester_id, new.addressee_id, 'friend_accept');
  end if;
  return new;
end; $$;

drop trigger if exists trg_notify_friendship on public.friendships;
create trigger trg_notify_friendship
  after insert or update on public.friendships
  for each row execute function public.notify_on_friendship();


-- ============================================================
--  2. MESSAGERIE : politiques fiables (sans "to authenticated")
--     + réservée aux AMIS
-- ============================================================
-- Conversations
drop policy if exists "créer une conversation" on public.conversations;
drop policy if exists "voir ses conversations" on public.conversations;
drop policy if exists "conv_insert" on public.conversations;
drop policy if exists "conv_select" on public.conversations;
create policy "conv_insert" on public.conversations for insert
  with check ( auth.uid() is not null );
create policy "conv_select" on public.conversations for select
  using ( public.is_conversation_member(id) );

-- Messages
drop policy if exists "lire les messages de ses conversations" on public.messages;
drop policy if exists "envoyer un message" on public.messages;
drop policy if exists "msg_insert" on public.messages;
drop policy if exists "msg_select" on public.messages;
create policy "msg_insert" on public.messages for insert
  with check ( auth.uid() = sender_id and public.is_conversation_member(conversation_id) );
create policy "msg_select" on public.messages for select
  using ( public.is_conversation_member(conversation_id) );

-- Fonction : suis-je ami avec `other` ?
create or replace function public.are_friends(other uuid)
returns boolean language sql security definer set search_path = public as $$
  select exists (
    select 1 from public.friendships
    where status = 'accepted'
      and ( (requester_id = auth.uid() and addressee_id = other)
         or (requester_id = other and addressee_id = auth.uid()) )
  );
$$;

-- Ajout de membres : moi-même OU un ami OU déjà membre (groupes plus tard)
drop policy if exists "s'ajouter / ajouter à une conversation" on public.conversation_members;
drop policy if exists "ajouter des participants" on public.conversation_members;
drop policy if exists "cm_insert" on public.conversation_members;
drop policy if exists "voir les membres de ses conversations" on public.conversation_members;
drop policy if exists "cm_select" on public.conversation_members;
create policy "cm_insert" on public.conversation_members for insert
  with check (
    auth.uid() = user_id
    or public.are_friends(user_id)
    or public.is_conversation_member(conversation_id)
  );
create policy "cm_select" on public.conversation_members for select
  using ( public.is_conversation_member(conversation_id) );


-- ============================================================
--  3. PHOTOS MULTIPLES + GROUPES (ouverts/validation, adhésions)
-- ============================================================
-- Photos multiples sur les publications
alter table public.posts
  add column if not exists images text[] default '{}';

-- Type de groupe : ouvert (false) ou sur validation (true)
alter table public.groups
  add column if not exists is_private boolean default false;

-- L'owner peut accepter (update) / retirer (delete) des membres
drop policy if exists "owner gère les membres" on public.group_members;
create policy "owner gère les membres" on public.group_members for update
  using ( exists (select 1 from public.groups g
                  where g.id = group_id and g.owner_id = auth.uid()) );

drop policy if exists "owner retire un membre" on public.group_members;
create policy "owner retire un membre" on public.group_members for delete
  using ( auth.uid() = user_id
          or exists (select 1 from public.groups g
                     where g.id = group_id and g.owner_id = auth.uid()) );

-- Pages d'établissement / club (réutilisent la table groups)
alter table public.groups add column if not exists kind text default 'group';
alter table public.groups add column if not exists category text;
alter table public.groups add column if not exists address text;
alter table public.groups add column if not exists phone text;
alter table public.groups add column if not exists website text;


-- ============================================================
--  4. TEMPS RÉEL (messagerie + notifications instantanées)
--     Ignorer l'erreur si la table est déjà dans la publication.
-- ============================================================
do $$
begin
  begin
    alter publication supabase_realtime add table public.messages;
  exception when duplicate_object then null; end;
  begin
    alter publication supabase_realtime add table public.notifications;
  exception when duplicate_object then null; end;
end $$;


-- ============================================================
--  5. LECTURES FIABLES : remplace les "auth.role() = 'authenticated'"
--     (fragiles avec les nouvelles clés JWT) par "auth.uid() is not null".
--     Couvre les 9 tables à lecture ouverte aux membres connectés.
--     Idempotent : sûr à ré-exécuter.
-- ============================================================
drop policy if exists "profils visibles par les membres" on public.profiles;
drop policy if exists "profiles_select" on public.profiles;
create policy "profiles_select" on public.profiles for select using ( auth.uid() is not null );

drop policy if exists "abonnements visibles" on public.follows;
drop policy if exists "follows_select" on public.follows;
create policy "follows_select" on public.follows for select using ( auth.uid() is not null );

drop policy if exists "publications visibles par les membres" on public.posts;
drop policy if exists "posts_select" on public.posts;
create policy "posts_select" on public.posts for select using ( auth.uid() is not null );

drop policy if exists "commentaires visibles" on public.comments;
drop policy if exists "comments_select" on public.comments;
create policy "comments_select" on public.comments for select using ( auth.uid() is not null );

drop policy if exists "likes visibles" on public.likes;
drop policy if exists "likes_select" on public.likes;
create policy "likes_select" on public.likes for select using ( auth.uid() is not null );

drop policy if exists "événements visibles" on public.events;
drop policy if exists "events_select" on public.events;
create policy "events_select" on public.events for select using ( auth.uid() is not null );

drop policy if exists "participations visibles" on public.event_attendees;
drop policy if exists "event_attendees_select" on public.event_attendees;
create policy "event_attendees_select" on public.event_attendees for select using ( auth.uid() is not null );

drop policy if exists "groupes visibles" on public.groups;
drop policy if exists "groups_select" on public.groups;
create policy "groups_select" on public.groups for select using ( auth.uid() is not null );

drop policy if exists "membres visibles" on public.group_members;
drop policy if exists "group_members_select" on public.group_members;
create policy "group_members_select" on public.group_members for select using ( auth.uid() is not null );

-- ============================================================
--  6. MODÉRATION & BLOCAGE
-- ============================================================
-- Blocage d'utilisateurs
create table if not exists public.blocks (
  blocker_id uuid references public.profiles(id) on delete cascade not null,
  blocked_id uuid references public.profiles(id) on delete cascade not null,
  created_at timestamptz default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
alter table public.blocks enable row level security;
drop policy if exists "voir mes blocages" on public.blocks;
create policy "voir mes blocages" on public.blocks for select using ( auth.uid() = blocker_id );
drop policy if exists "bloquer" on public.blocks;
create policy "bloquer" on public.blocks for insert with check ( auth.uid() = blocker_id );
drop policy if exists "débloquer" on public.blocks;
create policy "débloquer" on public.blocks for delete using ( auth.uid() = blocker_id );

-- Signalements : colonnes complémentaires
alter table public.reports add column if not exists target_type text;
alter table public.reports add column if not exists details text;

-- Admin
alter table public.profiles add column if not exists is_admin boolean default false;
alter table public.profiles add column if not exists is_banned boolean default false;
create or replace function public.is_admin()
returns boolean language sql security definer set search_path = public as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;
drop policy if exists "admin voit les signalements" on public.reports;
create policy "admin voit les signalements" on public.reports for select using ( public.is_admin() );
drop policy if exists "admin met à jour les signalements" on public.reports;
create policy "admin met à jour les signalements" on public.reports for update using ( public.is_admin() );
drop policy if exists "admin supprime un post" on public.posts;
create policy "admin supprime un post" on public.posts for delete using ( auth.uid() = author_id or public.is_admin() );
drop policy if exists "admin gère les profils" on public.profiles;
create policy "admin gère les profils" on public.profiles for update using ( auth.uid() = id or public.is_admin() );

-- >>> POUR TE DÉSIGNER ADMIN (remplace par TON email) :
--     update public.profiles set is_admin = true
--     where id = (select id from auth.users where email = 'TON-EMAIL@exemple.ch');


-- ============================================================
--  7. GROUPES : ADMINISTRATEURS + RÈGLES + COUVERTURE (façon FB)
--     Owner ET admins peuvent éditer le groupe et gérer les membres.
--     L'owner est protégé (non rétrogradable, propriété verrouillée).
-- ============================================================
alter table public.groups add column if not exists rules text;

create or replace function public.is_group_manager(gid uuid)
returns boolean language sql security definer set search_path = public as $$
  select exists (
    select 1 from public.groups g where g.id = gid and g.owner_id = auth.uid()
  ) or exists (
    select 1 from public.group_members m
    where m.group_id = gid and m.user_id = auth.uid() and m.role = 'admin'
  );
$$;

drop policy if exists "modifier son groupe" on public.groups;
drop policy if exists "gerer le groupe" on public.groups;
create policy "gerer le groupe" on public.groups for update
  using ( public.is_group_manager(id) );

create or replace function public.protect_group_owner()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.owner_id is distinct from old.owner_id and old.owner_id <> auth.uid() then
    new.owner_id := old.owner_id;
  end if;
  return new;
end; $$;
drop trigger if exists trg_protect_group_owner on public.groups;
create trigger trg_protect_group_owner
  before update on public.groups
  for each row execute function public.protect_group_owner();

drop policy if exists "owner gère les membres" on public.group_members;
drop policy if exists "managers gerent les membres" on public.group_members;
create policy "managers gerent les membres" on public.group_members for update
  using ( public.is_group_manager(group_id) and role <> 'owner' )
  with check ( role in ('member','admin','pending') );

drop policy if exists "quitter un groupe" on public.group_members;
drop policy if exists "owner retire un membre" on public.group_members;
drop policy if exists "retirer un membre" on public.group_members;
create policy "retirer un membre" on public.group_members for delete
  using ( auth.uid() = user_id
          or ( public.is_group_manager(group_id) and role <> 'owner' ) );


-- ============================================================
--  8. LIKES SUR LES COMMENTAIRES (tri « le plus aimé », façon FB)
-- ============================================================
create table if not exists public.comment_likes (
  comment_id uuid references public.comments(id) on delete cascade,
  user_id    uuid references public.profiles(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (comment_id, user_id)
);
alter table public.comment_likes enable row level security;
drop policy if exists "comment_likes_select" on public.comment_likes;
create policy "comment_likes_select" on public.comment_likes for select using ( auth.uid() is not null );
drop policy if exists "aimer un commentaire" on public.comment_likes;
create policy "aimer un commentaire" on public.comment_likes for insert with check ( auth.uid() = user_id );
drop policy if exists "retirer son like de commentaire" on public.comment_likes;
create policy "retirer son like de commentaire" on public.comment_likes for delete using ( auth.uid() = user_id );


-- ============================================================
--  9. MARKETPLACE / PETITES ANNONCES (acheter · vendre · donner)
-- ============================================================
create table if not exists public.listings (
  id          uuid primary key default gen_random_uuid(),
  seller_id   uuid references public.profiles(id) on delete cascade not null,
  title       text not null,
  description text,
  price       numeric(10,2),
  category    text default 'Divers',
  town        text,
  images      text[] default '{}',
  status      text default 'active',
  created_at  timestamptz default now()
);
create index if not exists listings_created_idx on public.listings(created_at desc);
create index if not exists listings_seller_idx  on public.listings(seller_id);
alter table public.listings enable row level security;
drop policy if exists "listings_select" on public.listings;
create policy "listings_select" on public.listings for select using ( auth.uid() is not null );
drop policy if exists "creer une annonce" on public.listings;
create policy "creer une annonce" on public.listings for insert with check ( auth.uid() = seller_id );
drop policy if exists "modifier son annonce" on public.listings;
create policy "modifier son annonce" on public.listings for update using ( auth.uid() = seller_id );
drop policy if exists "supprimer son annonce" on public.listings;
create policy "supprimer son annonce" on public.listings for delete using ( auth.uid() = seller_id );


-- ============================================================
--  10. REPARTAGE DE PUBLICATIONS (une publication en repartage une autre)
-- ============================================================
alter table public.posts
  add column if not exists shared_post_id uuid references public.posts(id) on delete set null;
create index if not exists posts_shared_idx on public.posts(shared_post_id);


-- ============================================================
--  11. AVIS & NOTES (étoiles) sur les Pages
-- ============================================================
create table if not exists public.page_reviews (
  id         uuid primary key default gen_random_uuid(),
  page_id    uuid references public.groups(id) on delete cascade not null,
  author_id  uuid references public.profiles(id) on delete cascade not null,
  rating     int not null check (rating between 1 and 5),
  text       text,
  created_at timestamptz default now(),
  unique (page_id, author_id)
);
create index if not exists page_reviews_page_idx on public.page_reviews(page_id);
alter table public.page_reviews enable row level security;
drop policy if exists "avis visibles" on public.page_reviews;
create policy "avis visibles" on public.page_reviews for select using ( auth.uid() is not null );
drop policy if exists "laisser un avis" on public.page_reviews;
create policy "laisser un avis" on public.page_reviews for insert with check ( auth.uid() = author_id );
drop policy if exists "modifier son avis" on public.page_reviews;
create policy "modifier son avis" on public.page_reviews for update using ( auth.uid() = author_id );
drop policy if exists "supprimer son avis" on public.page_reviews;
create policy "supprimer son avis" on public.page_reviews for delete using ( auth.uid() = author_id );


-- ============================================================
--  12. RÉACTIONS MULTIPLES (like 👍 love ❤️ haha 😆 wow 😮 sad 😢)
--     On ajoute un type sur la table likes (1 réaction par personne).
-- ============================================================
alter table public.likes add column if not exists type text default 'like';


-- ============================================================
--  13. CONTACTER UN VENDEUR (Marché) sans être amis
--     Fonction dédiée (SECURITY DEFINER) : crée/retrouve une
--     conversation 1-à-1. La messagerie reste amis-only ailleurs.
-- ============================================================
create or replace function public.contact_user(other_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare conv uuid;
begin
  if other_id is null or other_id = auth.uid() then
    raise exception 'destinataire invalide';
  end if;
  select c.id into conv
  from public.conversations c
  where coalesce(c.is_group, false) = false
    and exists (select 1 from public.conversation_members m where m.conversation_id = c.id and m.user_id = auth.uid())
    and exists (select 1 from public.conversation_members m where m.conversation_id = c.id and m.user_id = other_id)
    and (select count(*) from public.conversation_members m where m.conversation_id = c.id) = 2
  limit 1;
  if conv is not null then return conv; end if;
  insert into public.conversations (is_group) values (false) returning id into conv;
  insert into public.conversation_members (conversation_id, user_id)
  values (conv, auth.uid()), (conv, other_id);
  return conv;
end; $$;
grant execute on function public.contact_user(uuid) to authenticated, anon;


-- ============================================================
--  14. ÉDITION DES COMMENTAIRES (policy UPDATE manquante)
-- ============================================================
drop policy if exists "modifier ses commentaires" on public.comments;
create policy "modifier ses commentaires" on public.comments for update
  using ( auth.uid() = author_id );


-- ============================================================
--  15. RÉPONSES AUX COMMENTAIRES (fils, 1 niveau d'imbrication)
-- ============================================================
alter table public.comments
  add column if not exists parent_id uuid references public.comments(id) on delete cascade;
create index if not exists comments_parent_idx on public.comments(parent_id);


-- ============================================================
--  16. SUGGESTIONS D'AMIS (amis communs prioritaires)
-- ============================================================
create or replace function public.friend_suggestions(lim int default 10)
returns table(user_id uuid, mutual int)
language sql security definer set search_path = public as $$
  with me as (select auth.uid() as id),
  myfriends as (
    select case when requester_id = (select id from me) then addressee_id else requester_id end as fid
    from public.friendships
    where status = 'accepted' and (select id from me) in (requester_id, addressee_id)
  ),
  pending as (
    select case when requester_id = (select id from me) then addressee_id else requester_id end as pid
    from public.friendships
    where status = 'pending' and (select id from me) in (requester_id, addressee_id)
  ),
  fof as (
    select case when f.requester_id = mf.fid then f.addressee_id else f.requester_id end as cand
    from public.friendships f
    join myfriends mf on mf.fid in (f.requester_id, f.addressee_id)
    where f.status = 'accepted'
  )
  select cand as user_id, count(*)::int as mutual
  from fof
  where cand <> (select id from me)
    and cand not in (select fid from myfriends)
    and cand not in (select pid from pending)
    and cand not in (select blocked_id from public.blocks where blocker_id = (select id from me))
  group by cand order by mutual desc limit lim;
$$;
grant execute on function public.friend_suggestions(int) to authenticated, anon;


-- ============================================================
--  17. @MENTIONS (notifier les personnes mentionnées @[Nom](uuid))
-- ============================================================
create or replace function public.notify_on_mention()
returns trigger language plpgsql security definer set search_path = public as $$
declare m record; uid uuid; pid uuid; actor uuid;
begin
  actor := NEW.author_id;
  -- IF/ELSE (et pas un CASE en une expression) : sinon Postgres résout
  -- NEW.post_id même sur la table posts (qui n'a pas ce champ) -> 42703.
  if TG_TABLE_NAME = 'comments' then
    pid := NEW.post_id;
  else
    pid := NEW.id;
  end if;
  for m in
    select (regexp_matches(NEW.text, '@\[[^\]]+\]\(([0-9a-fA-F-]{36})\)', 'g'))[1] as id
  loop
    begin uid := m.id::uuid; exception when others then uid := null; end;
    if uid is not null and uid <> actor then
      insert into public.notifications (user_id, actor_id, type, post_id)
      values (uid, actor, 'mention', pid);
    end if;
  end loop;
  return NEW;
end; $$;
drop trigger if exists trg_notify_mention_post on public.posts;
create trigger trg_notify_mention_post after insert on public.posts
  for each row execute function public.notify_on_mention();
drop trigger if exists trg_notify_mention_comment on public.comments;
create trigger trg_notify_mention_comment after insert on public.comments
  for each row execute function public.notify_on_mention();


-- ============================================================
--  18. ÉVÉNEMENTS ENRICHIS (Intéressé + discussion)
-- ============================================================
alter table public.event_attendees add column if not exists status text default 'going';

create table if not exists public.event_comments (
  id         uuid primary key default gen_random_uuid(),
  event_id   uuid references public.events(id) on delete cascade not null,
  author_id  uuid references public.profiles(id) on delete cascade not null,
  text       text not null,
  created_at timestamptz default now()
);
create index if not exists event_comments_event_idx on public.event_comments(event_id, created_at);
alter table public.event_comments enable row level security;
drop policy if exists "discussion visible" on public.event_comments;
create policy "discussion visible" on public.event_comments for select using ( auth.uid() is not null );
drop policy if exists "commenter un evenement" on public.event_comments;
create policy "commenter un evenement" on public.event_comments for insert with check ( auth.uid() = author_id );
drop policy if exists "modifier son commentaire evenement" on public.event_comments;
create policy "modifier son commentaire evenement" on public.event_comments for update using ( auth.uid() = author_id );
drop policy if exists "supprimer son commentaire evenement" on public.event_comments;
create policy "supprimer son commentaire evenement" on public.event_comments for delete using ( auth.uid() = author_id );


-- ============================================================
--  19. ÉVÉNEMENTS : date de fin + photos (cover_url existe déjà)
-- ============================================================
alter table public.events add column if not exists ends_at timestamptz;
alter table public.events add column if not exists images text[] default '{}';


-- ============================================================
--  20. SUPPRESSION DE COMPTE (nLPD / droit à l'effacement)
-- ============================================================
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'non authentifié'; end if;
  delete from auth.users where id = auth.uid();
end; $$;
grant execute on function public.delete_my_account() to authenticated;


-- ============================================================
--  21. RÉGIE PUBLICITAIRE (pubs dans le fil, gestion admin)
--      Pubs gérées par les admins (RLS : tout réservé aux admins).
--      Affichage via active_ads(device) : seulement actives, dans
--      leurs dates, sous le plafond mensuel. ad_impression(id)
--      compte un affichage (compteur mensuel auto-réinitialisé).
-- ============================================================
create table if not exists public.ads (
  id              uuid primary key default gen_random_uuid(),
  title           text,
  body            text,
  advertiser      text,
  contact         text,
  image_pc        text,
  image_mobile    text,
  link_url        text,
  active          boolean default true,
  sort_order      int default 0,
  impressions_cap int default 3000,
  impressions     int default 0,
  month_key       text,
  plan            text,
  starts_on       date,
  ends_on         date,
  created_at      timestamptz default now()
);
alter table public.ads add column if not exists body text;
create index if not exists ads_order_idx on public.ads(sort_order, created_at);

alter table public.ads enable row level security;
drop policy if exists "ads admin" on public.ads;
create policy "ads admin" on public.ads for all
  using ( public.is_admin() ) with check ( public.is_admin() );

drop function if exists public.active_ads(text);
create or replace function public.active_ads(device text)
returns table(id uuid, image text, link text, title text, body text)
language sql security definer set search_path = public as $$
  select a.id,
         case when device='mobile' then coalesce(a.image_mobile, a.image_pc)
              else coalesce(a.image_pc, a.image_mobile) end as image,
         a.link_url as link, a.title, a.body
  from public.ads a
  where a.active = true
    and (a.starts_on is null or a.starts_on <= current_date)
    and (a.ends_on   is null or a.ends_on   >= current_date)
    and (case when a.month_key = to_char(now(),'YYYY-MM') then a.impressions else 0 end) < a.impressions_cap
    and (case when device='mobile' then coalesce(a.image_mobile,a.image_pc)
              else coalesce(a.image_pc,a.image_mobile) end) is not null
  order by a.sort_order, a.created_at;
$$;
grant execute on function public.active_ads(text) to authenticated, anon;

alter table public.ads add column if not exists clicks int default 0;

create or replace function public.ad_impression(ad_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare mk text := to_char(now(),'YYYY-MM');
begin
  update public.ads
     set impressions = case when month_key = mk then impressions + 1 else 1 end,
         clicks      = case when month_key = mk then clicks else 0 end,
         month_key   = mk
   where id = ad_id;
end; $$;
grant execute on function public.ad_impression(uuid) to authenticated, anon;

create or replace function public.ad_click(ad_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare mk text := to_char(now(),'YYYY-MM');
begin
  update public.ads
     set clicks      = case when month_key = mk then clicks + 1 else 1 end,
         impressions = case when month_key = mk then impressions else 0 end,
         month_key   = mk
   where id = ad_id;
end; $$;
grant execute on function public.ad_click(uuid) to authenticated, anon;


-- ============================================================
--  22. SONDAGES dans les publications
--      Options stockées sur le post (poll_options) ; un membre = un
--      vote (poll_votes), modifiable / retirable.
-- ============================================================
alter table public.posts add column if not exists poll_options text[];

create table if not exists public.poll_votes (
  post_id    uuid references public.posts(id) on delete cascade,
  user_id    uuid references public.profiles(id) on delete cascade,
  choice     int not null,
  created_at timestamptz default now(),
  primary key (post_id, user_id)
);
alter table public.poll_votes enable row level security;
drop policy if exists "poll_votes_select" on public.poll_votes;
create policy "poll_votes_select" on public.poll_votes for select using ( auth.uid() is not null );
drop policy if exists "voter a un sondage" on public.poll_votes;
create policy "voter a un sondage" on public.poll_votes for insert with check ( auth.uid() = user_id );
drop policy if exists "changer son vote" on public.poll_votes;
create policy "changer son vote" on public.poll_votes for update using ( auth.uid() = user_id );
drop policy if exists "retirer son vote" on public.poll_votes;
create policy "retirer son vote" on public.poll_votes for delete using ( auth.uid() = user_id );


-- ============================================================
--  23. NOTIFICATIONS PAR E-MAIL (préférence membre)
--      L'envoi est assuré par l'Edge Function « notify-email » +
--      un Database Webhook (voir notifications-email-GUIDE.md).
-- ============================================================
alter table public.profiles
  add column if not exists email_notifications boolean default true;


-- ============================================================
--  24. VIDÉOS dans les publications
--      Vidéo stockée dans le bucket Storage « posts », lue inline.
--      (Pense à relever la limite de taille du bucket si besoin.)
-- ============================================================
alter table public.posts add column if not exists video_url text;


-- ============================================================
--  25. APERÇU DE LIENS (Open Graph) sur les publications
--      Aperçu récupéré une fois à la publication (Edge Function
--      « og-preview ») et stocké sur le post. Voir le guide.
-- ============================================================
alter table public.posts add column if not exists link_url   text;
alter table public.posts add column if not exists link_title text;
alter table public.posts add column if not exists link_desc  text;
alter table public.posts add column if not exists link_image text;
alter table public.posts add column if not exists link_site  text;


-- ============================================================
--  26. SÉCURITÉ RLS (durcissement avant lancement)
--      - Anti-escalade : la policy UPDATE de profiles n'a pas de
--        WITH CHECK -> un membre pouvait se mettre is_admin=true sur
--        SA ligne. On verrouille is_admin/is_banned par trigger.
--      - poll_votes : ajout du WITH CHECK manquant sur l'UPDATE.
-- ============================================================
create or replace function public.protect_profile_privesc()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    new.is_admin  := old.is_admin;
    new.is_banned := old.is_banned;
  end if;
  return new;
end; $$;
drop trigger if exists trg_protect_profile_privesc on public.profiles;
create trigger trg_protect_profile_privesc
  before update on public.profiles
  for each row execute function public.protect_profile_privesc();

drop policy if exists "changer son vote" on public.poll_votes;
create policy "changer son vote" on public.poll_votes for update
  using ( auth.uid() = user_id ) with check ( auth.uid() = user_id );


-- ============================================================
--  27. MODE D'ENVOI DES E-MAILS (instantané / quotidien / off)
--      'instant' (défaut, notify-email), 'daily' (notify-digest +
--      pg_cron), 'off'. Voir notifications-digest-GUIDE.md.
-- ============================================================
alter table public.profiles add column if not exists email_mode text default 'instant';
update public.profiles set email_mode = 'off'
where email_mode is null and email_notifications = false;
update public.profiles set email_mode = 'instant' where email_mode is null;


-- ============================================================
--  28. NOTIFICATIONS PUSH (Web Push / PWA)
--      Abonnements par appareil ; envoi par l'Edge Function
--      « notify-push » (webhook sur notifications). Voir push-GUIDE.md.
-- ============================================================
create table if not exists public.push_subscriptions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references public.profiles(id) on delete cascade not null,
  endpoint   text not null unique,
  p256dh     text not null,
  auth       text not null,
  created_at timestamptz default now()
);
create index if not exists push_subs_user_idx on public.push_subscriptions(user_id);
alter table public.push_subscriptions enable row level security;
drop policy if exists "push_subs_select" on public.push_subscriptions;
create policy "push_subs_select" on public.push_subscriptions for select using ( auth.uid() = user_id );
drop policy if exists "push_subs_insert" on public.push_subscriptions;
create policy "push_subs_insert" on public.push_subscriptions for insert with check ( auth.uid() = user_id );
drop policy if exists "push_subs_update" on public.push_subscriptions;
create policy "push_subs_update" on public.push_subscriptions for update using ( auth.uid() = user_id ) with check ( auth.uid() = user_id );
drop policy if exists "push_subs_delete" on public.push_subscriptions;
create policy "push_subs_delete" on public.push_subscriptions for delete using ( auth.uid() = user_id );


-- ============================================================
--  29. STORIES ÉPHÉMÈRES (24 h)
--      Image/vidéo + texte, expire après 24 h (RLS). story_views =
--      qui a vu quoi (anneau « non vu » + compteur). Voir stories.sql.
-- ============================================================
create table if not exists public.stories (
  id         uuid primary key default gen_random_uuid(),
  author_id  uuid references public.profiles(id) on delete cascade not null,
  media_url  text not null,
  media_type text default 'image',
  text       text,
  created_at timestamptz default now(),
  expires_at timestamptz not null default (now() + interval '24 hours')
);
create index if not exists stories_active_idx on public.stories(expires_at);
create index if not exists stories_author_idx on public.stories(author_id, created_at);
alter table public.stories enable row level security;
drop policy if exists "stories actives visibles" on public.stories;
create policy "stories actives visibles" on public.stories for select
  using ( auth.uid() is not null and expires_at > now() );
drop policy if exists "publier une story" on public.stories;
create policy "publier une story" on public.stories for insert with check ( auth.uid() = author_id );
drop policy if exists "supprimer sa story" on public.stories;
create policy "supprimer sa story" on public.stories for delete using ( auth.uid() = author_id );

create table if not exists public.story_views (
  story_id   uuid references public.stories(id) on delete cascade,
  user_id    uuid references public.profiles(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (story_id, user_id)
);
alter table public.story_views enable row level security;
drop policy if exists "vues visibles" on public.story_views;
create policy "vues visibles" on public.story_views for select using ( auth.uid() is not null );
drop policy if exists "marquer vu" on public.story_views;
create policy "marquer vu" on public.story_views for insert with check ( auth.uid() = user_id );


-- ============================================================
--  30. COMMUNE SUR LES PUBLICATIONS (filtre local du fil)
--      posts.town = commune de l'auteur (dénormalisée). Remplie à la
--      publication côté app ; backfill des posts existants ici.
-- ============================================================
alter table public.posts add column if not exists town text;
create index if not exists posts_town_idx on public.posts(town);
update public.posts p set town = pr.town
  from public.profiles pr where p.author_id = pr.id and p.town is null;


-- ============================================================
--  31. MESSAGERIE DE GROUPE (policies : quitter / renommer)
--      Le schéma gère déjà is_group + title ; on autorise le delete
--      de sa propre adhésion et l'update du titre par un membre.
-- ============================================================
drop policy if exists "cm_delete" on public.conversation_members;
create policy "cm_delete" on public.conversation_members for delete
  using ( auth.uid() = user_id );
drop policy if exists "conv_update" on public.conversations;
create policy "conv_update" on public.conversations for update
  using ( public.is_conversation_member(id) ) with check ( public.is_conversation_member(id) );


-- ============================================================
--  32. PROFIL ENRICHI (« À propos » : métier, origine, site)
-- ============================================================
alter table public.profiles add column if not exists job     text;
alter table public.profiles add column if not exists origin  text;
alter table public.profiles add column if not exists website text;


-- ============================================================
--  33. PROFIL : anniversaire, formation, situation amoureuse
-- ============================================================
alter table public.profiles add column if not exists birthday        date;
alter table public.profiles add column if not exists show_birth_year boolean default false;
alter table public.profiles add column if not exists school          text;
alter table public.profiles add column if not exists relationship    text;


-- ============================================================
--  34. ALBUMS PHOTOS (profil)
-- ============================================================
create table if not exists public.albums (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles(id) on delete cascade not null,
  title text not null, cover_url text, created_at timestamptz default now()
);
create index if not exists albums_owner_idx on public.albums(owner_id, created_at desc);
create table if not exists public.album_photos (
  id uuid primary key default gen_random_uuid(),
  album_id uuid references public.albums(id) on delete cascade not null,
  owner_id uuid references public.profiles(id) on delete cascade not null,
  url text not null, created_at timestamptz default now()
);
create index if not exists album_photos_album_idx on public.album_photos(album_id, created_at);
alter table public.albums enable row level security;
alter table public.album_photos enable row level security;
drop policy if exists "albums_select" on public.albums;
create policy "albums_select" on public.albums for select using ( auth.uid() is not null );
drop policy if exists "albums_insert" on public.albums;
create policy "albums_insert" on public.albums for insert with check ( auth.uid() = owner_id );
drop policy if exists "albums_update" on public.albums;
create policy "albums_update" on public.albums for update using ( auth.uid() = owner_id );
drop policy if exists "albums_delete" on public.albums;
create policy "albums_delete" on public.albums for delete using ( auth.uid() = owner_id );
drop policy if exists "album_photos_select" on public.album_photos;
create policy "album_photos_select" on public.album_photos for select using ( auth.uid() is not null );
drop policy if exists "album_photos_insert" on public.album_photos;
create policy "album_photos_insert" on public.album_photos for insert with check ( auth.uid() = owner_id );
drop policy if exists "album_photos_delete" on public.album_photos;
create policy "album_photos_delete" on public.album_photos for delete using ( auth.uid() = owner_id );


-- ============================================================
--  35. REELS (vidéos verticales courtes, type FB/Insta)
--  Un reel = une publication avec is_reel=true (vidéo verticale).
--  Exclu du fil normal ; affiché dans le carrousel + lecteur plein écran.
-- ============================================================
alter table public.posts add column if not exists is_reel boolean not null default false;
create index if not exists posts_reel_idx on public.posts(created_at desc) where is_reel = true;
notify pgrst, 'reload schema';


-- ============================================================
--  36. TAGS DE PERSONNES SUR LES PHOTOS
--  L'auteur d'une publication identifie des amis ; ceux-ci sont notifiés.
-- ============================================================
create table if not exists public.photo_tags (
  id uuid primary key default gen_random_uuid(),
  post_id   uuid references public.posts(id)    on delete cascade not null,
  tagged_id uuid references public.profiles(id) on delete cascade not null,
  tagger_id uuid references public.profiles(id) on delete cascade not null,
  created_at timestamptz default now(),
  unique(post_id, tagged_id)
);
create index if not exists photo_tags_post_idx   on public.photo_tags(post_id);
create index if not exists photo_tags_tagged_idx on public.photo_tags(tagged_id);
alter table public.photo_tags enable row level security;
drop policy if exists "phototags_select" on public.photo_tags;
create policy "phototags_select" on public.photo_tags for select using ( auth.uid() is not null );
drop policy if exists "phototags_insert" on public.photo_tags;
create policy "phototags_insert" on public.photo_tags for insert with check (
  auth.uid() = tagger_id
  and exists (select 1 from public.posts p where p.id = post_id and p.author_id = auth.uid())
);
drop policy if exists "phototags_delete" on public.photo_tags;
create policy "phototags_delete" on public.photo_tags for delete using (
  auth.uid() = tagger_id or auth.uid() = tagged_id
);
create or replace function public.notify_on_phototag()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if NEW.tagged_id <> NEW.tagger_id then
    insert into public.notifications (user_id, actor_id, type, post_id)
    values (NEW.tagged_id, NEW.tagger_id, 'phototag', NEW.post_id);
  end if;
  return NEW;
end; $$;
drop trigger if exists trg_notify_phototag on public.photo_tags;
create trigger trg_notify_phototag after insert on public.photo_tags
  for each row execute function public.notify_on_phototag();
notify pgrst, 'reload schema';


-- ============================================================
--  37. RÉACTIONS SUR LES MESSAGES (👍❤️😆😮😢🙏)
--  Une réaction par personne et par message (modifiable).
-- ============================================================
create table if not exists public.message_reactions (
  id uuid primary key default gen_random_uuid(),
  message_id uuid references public.messages(id)  on delete cascade not null,
  user_id    uuid references public.profiles(id)  on delete cascade not null,
  emoji text not null,
  created_at timestamptz default now(),
  unique(message_id, user_id)
);
create index if not exists msg_react_msg_idx on public.message_reactions(message_id);
alter table public.message_reactions enable row level security;
drop policy if exists "msgreact_select" on public.message_reactions;
create policy "msgreact_select" on public.message_reactions for select using (
  exists (select 1 from public.messages m where m.id = message_id and public.is_conversation_member(m.conversation_id))
);
drop policy if exists "msgreact_insert" on public.message_reactions;
create policy "msgreact_insert" on public.message_reactions for insert with check (
  auth.uid() = user_id
  and exists (select 1 from public.messages m where m.id = message_id and public.is_conversation_member(m.conversation_id))
);
drop policy if exists "msgreact_update" on public.message_reactions;
create policy "msgreact_update" on public.message_reactions for update using ( auth.uid() = user_id );
drop policy if exists "msgreact_delete" on public.message_reactions;
create policy "msgreact_delete" on public.message_reactions for delete using ( auth.uid() = user_id );
notify pgrst, 'reload schema';


-- ============================================================
--  38. MODÉRATION RENFORCÉE : mots interdits + file d'attente
--  Les posts/commentaires contenant un mot interdit sont auto-signalés
--  dans une file d'attente (mod_queue) pour examen admin (sans blocage).
-- ============================================================
create table if not exists public.banned_words (
  id uuid primary key default gen_random_uuid(),
  word text unique not null,
  created_at timestamptz default now()
);
alter table public.banned_words enable row level security;
drop policy if exists "bw_select" on public.banned_words;
create policy "bw_select" on public.banned_words for select using ( public.is_admin() );
drop policy if exists "bw_insert" on public.banned_words;
create policy "bw_insert" on public.banned_words for insert with check ( public.is_admin() );
drop policy if exists "bw_delete" on public.banned_words;
create policy "bw_delete" on public.banned_words for delete using ( public.is_admin() );

create table if not exists public.mod_queue (
  id uuid primary key default gen_random_uuid(),
  target_type text not null,            -- 'post' | 'comment'
  target_id uuid not null,
  author_id uuid references public.profiles(id) on delete set null,
  content text,
  matched_word text,
  status text default 'open',           -- 'open' | 'reviewed' | 'dismissed'
  created_at timestamptz default now()
);
create index if not exists mod_queue_status_idx on public.mod_queue(status, created_at desc);
alter table public.mod_queue enable row level security;
drop policy if exists "mq_select" on public.mod_queue;
create policy "mq_select" on public.mod_queue for select using ( public.is_admin() );
drop policy if exists "mq_update" on public.mod_queue;
create policy "mq_update" on public.mod_queue for update using ( public.is_admin() );
drop policy if exists "mq_delete" on public.mod_queue;
create policy "mq_delete" on public.mod_queue for delete using ( public.is_admin() );

-- Trigger : auto-signalement si un mot interdit est présent (posts ET comments).
-- NEW.text / NEW.author_id / NEW.id existent sur les deux tables -> pas de 42703.
create or replace function public.flag_banned_words()
returns trigger language plpgsql security definer set search_path = public as $$
declare w text; ttype text;
begin
  if NEW.text is null or NEW.text = '' then return NEW; end if;
  if TG_TABLE_NAME = 'comments' then ttype := 'comment'; else ttype := 'post'; end if;
  select word into w from public.banned_words
    where position(lower(word) in lower(NEW.text)) > 0 limit 1;
  if w is not null then
    insert into public.mod_queue (target_type, target_id, author_id, content, matched_word)
    values (ttype, NEW.id, NEW.author_id, left(NEW.text, 500), w);
  end if;
  return NEW;
end; $$;
drop trigger if exists trg_flag_words_post on public.posts;
create trigger trg_flag_words_post after insert on public.posts
  for each row execute function public.flag_banned_words();
drop trigger if exists trg_flag_words_comment on public.comments;
create trigger trg_flag_words_comment after insert on public.comments
  for each row execute function public.flag_banned_words();
notify pgrst, 'reload schema';


-- ============================================================
--  39. INDEX DE PERFORMANCE (montée en charge)
--  Couvre les colonnes les plus filtrées/triées des requêtes fréquentes.
--  Idempotent (create index if not exists).
-- ============================================================
create index if not exists posts_author_idx        on public.posts(author_id, created_at desc);
create index if not exists posts_created_idx        on public.posts(created_at desc);
create index if not exists comments_post_idx        on public.comments(post_id, created_at);
create index if not exists likes_post_idx           on public.likes(post_id);
create index if not exists comment_likes_cid_idx    on public.comment_likes(comment_id);
create index if not exists poll_votes_post_idx      on public.poll_votes(post_id);
create index if not exists notifications_user_idx   on public.notifications(user_id, read, created_at desc);
create index if not exists conv_members_user_idx    on public.conversation_members(user_id);
create index if not exists conv_members_conv_idx    on public.conversation_members(conversation_id);
create index if not exists messages_conv_idx        on public.messages(conversation_id, created_at);
create index if not exists follows_followee_idx     on public.follows(followee_id);
create index if not exists listings_town_idx        on public.listings(town, created_at desc);
create index if not exists events_town_idx          on public.events(town, starts_at);
create index if not exists photo_tags_tagger_idx    on public.photo_tags(tagger_id);


-- ============================================================
--  40-41. DASHBOARD ADMIN (présence + agrégats admin-only)
--  Détail identique dans supabase/dashboard-admin.sql.
-- ============================================================

-- ----- 40. Présence / activité -----
alter table public.profiles add column if not exists last_seen_at timestamptz;
create index if not exists profiles_last_seen_idx on public.profiles(last_seen_at);

create table if not exists public.user_activity (
  user_id uuid references public.profiles(id) on delete cascade,
  day date not null,
  primary key (user_id, day)
);
create index if not exists user_activity_day_idx on public.user_activity(day);
alter table public.user_activity enable row level security;
drop policy if exists "ua_self" on public.user_activity;
create policy "ua_self" on public.user_activity for select using ( auth.uid() = user_id );

-- Marque l'utilisateur courant comme actif (appelé au chargement de l'app, throttlé côté client)
create or replace function public.touch_last_seen()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return; end if;
  update public.profiles set last_seen_at = now() where id = auth.uid();
  insert into public.user_activity (user_id, day) values (auth.uid(), current_date)
    on conflict (user_id, day) do nothing;
end; $$;
grant execute on function public.touch_last_seen() to authenticated;


-- ----- 41. Fonctions d'agrégation (admin-only) -----

-- Vue d'ensemble (cartes chiffres)
create or replace function public.admin_stats_overview()
returns json language plpgsql security definer set search_path = public as $$
declare j json;
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  select json_build_object(
    'users_total',     (select count(*) from profiles),
    'users_today',     (select count(*) from profiles where created_at >= current_date),
    'users_7d',        (select count(*) from profiles where created_at >= now()-interval '7 days'),
    'active_today',    (select count(*) from profiles where last_seen_at >= current_date),
    'active_7d',       (select count(*) from profiles where last_seen_at >= now()-interval '7 days'),
    'active_30d',      (select count(*) from profiles where last_seen_at >= now()-interval '30 days'),
    'posts_total',     (select count(*) from posts where is_reel = false),
    'posts_today',     (select count(*) from posts where is_reel = false and created_at >= current_date),
    'posts_7d',        (select count(*) from posts where is_reel = false and created_at >= now()-interval '7 days'),
    'reels_total',     (select count(*) from posts where is_reel = true),
    'reels_7d',        (select count(*) from posts where is_reel = true and created_at >= now()-interval '7 days'),
    'comments_total',  (select count(*) from comments),
    'comments_7d',     (select count(*) from comments where created_at >= now()-interval '7 days'),
    'likes_total',     (select count(*) from likes),
    'likes_7d',        (select count(*) from likes where created_at >= now()-interval '7 days'),
    'groups_total',    (select count(*) from groups where coalesce(kind,'group')='group'),
    'groups_7d',       (select count(*) from groups where coalesce(kind,'group')='group' and created_at >= now()-interval '7 days'),
    'pages_total',     (select count(*) from groups where kind='page'),
    'pages_7d',        (select count(*) from groups where kind='page' and created_at >= now()-interval '7 days'),
    'listings_active', (select count(*) from listings where status='active'),
    'events_total',    (select count(*) from events),
    'events_upcoming', (select count(*) from events where starts_at >= now()),
    'messages_7d',     (select count(*) from messages where created_at >= now()-interval '7 days')
  ) into j;
  return j;
end; $$;
grant execute on function public.admin_stats_overview() to authenticated;

-- Croissance journalière (N derniers jours)
create or replace function public.admin_growth_daily(days int default 30)
returns table(day date, new_users int, posts int, active_users int)
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  return query
  with d as (
    select generate_series(current_date - (greatest(days,1)-1), current_date, interval '1 day')::date as day
  )
  select dd.day,
    (select count(*) from profiles p  where p.created_at::date  = dd.day)::int,
    (select count(*) from posts    po where po.created_at::date = dd.day)::int,
    (select count(*) from user_activity ua where ua.day = dd.day)::int
  from d dd order by dd.day;
end; $$;
grant execute on function public.admin_growth_daily(int) to authenticated;

-- Rétention (v1 : basée sur last_seen_at)
create or replace function public.admin_retention()
returns json language plpgsql security definer set search_path = public as $$
declare j json;
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  select json_build_object(
    'ratio_active', case when (select count(*) from profiles)=0 then 0
        else round(100.0*(select count(*) from profiles where last_seen_at >= now()-interval '7 days')
             / (select count(*) from profiles),1) end,
    'j1',  (select case when count(*)=0 then null else
              round(100.0*count(*) filter (where last_seen_at > created_at + interval '1 day')/count(*),1) end
            from profiles where created_at <= now()-interval '1 day'),
    'j7',  (select case when count(*)=0 then null else
              round(100.0*count(*) filter (where last_seen_at >= created_at + interval '7 days')/count(*),1) end
            from profiles where created_at <= now()-interval '7 days'),
    'j30', (select case when count(*)=0 then null else
              round(100.0*count(*) filter (where last_seen_at >= created_at + interval '30 days')/count(*),1) end
            from profiles where created_at <= now()-interval '30 days')
  ) into j;
  return j;
end; $$;
grant execute on function public.admin_retention() to authenticated;

-- Top communes (utilisateurs + posts)
create or replace function public.admin_top_towns()
returns table(town text, users int, posts int)
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  return query
  with u as (select town, count(*)::int c from profiles where town is not null and town <> '' group by town),
       p as (select town, count(*)::int c from posts    where town is not null and town <> '' group by town)
  select coalesce(u.town,p.town) as town, coalesce(u.c,0) as users, coalesce(p.c,0) as posts
  from u full outer join p on u.town = p.town
  order by users desc, posts desc
  limit 15;
end; $$;
grant execute on function public.admin_top_towns() to authenticated;

-- Business / pages établissement
create or replace function public.admin_business()
returns json language plpgsql security definer set search_path = public as $$
declare j json;
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  select json_build_object(
    'pages_total',   (select count(*) from groups where kind='page'),
    'pages_7d',      (select count(*) from groups where kind='page' and created_at >= now()-interval '7 days'),
    'pages_active',  (select count(*) from groups g where g.kind='page'
                        and exists (select 1 from posts po where po.group_id = g.id)),
    'reviews_total', (select count(*) from page_reviews),
    'reviews_avg',   (select coalesce(round(avg(rating)::numeric,2),0) from page_reviews)
  ) into j;
  return j;
end; $$;
grant execute on function public.admin_business() to authenticated;

-- Modération
create or replace function public.admin_moderation()
returns json language plpgsql security definer set search_path = public as $$
declare j json;
begin
  if not public.is_admin() then raise exception 'forbidden'; end if;
  select json_build_object(
    'reports_open',  (select count(*) from reports where status='open'),
    'reports_done',  (select count(*) from reports where status <> 'open'),
    'reports_oldest_days', (select coalesce(floor(extract(epoch from now()-min(created_at))/86400),0)
                            from reports where status='open'),
    'queue_open',    (select count(*) from mod_queue where status='open')
  ) into j;
  return j;
end; $$;
grant execute on function public.admin_moderation() to authenticated;


-- ============================================================
--  42. MESSAGERIE : images + réponse à un message
-- ============================================================
alter table public.messages add column if not exists image_url text;
alter table public.messages add column if not exists reply_to uuid references public.messages(id) on delete set null;
create index if not exists messages_reply_idx on public.messages(reply_to);
notify pgrst, 'reload schema';


-- ============================================================
--  43. MONITORING — journal des erreurs client (admin)
-- ============================================================
create table if not exists public.client_errors (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  message text, source text, detail text, ua text,
  created_at timestamptz default now()
);
create index if not exists client_errors_created_idx on public.client_errors(created_at desc);
alter table public.client_errors enable row level security;
drop policy if exists "cerr_insert" on public.client_errors;
create policy "cerr_insert" on public.client_errors for insert with check ( auth.uid() = user_id );
drop policy if exists "cerr_select" on public.client_errors;
create policy "cerr_select" on public.client_errors for select using ( public.is_admin() );
drop policy if exists "cerr_delete" on public.client_errors;
create policy "cerr_delete" on public.client_errors for delete using ( public.is_admin() );
notify pgrst, 'reload schema';


-- ============================================================
--  44. MESSAGERIE + : édition/suppression + lus/non-lus
-- ============================================================
alter table public.messages add column if not exists edited_at timestamptz;
drop policy if exists "msg_update" on public.messages;
create policy "msg_update" on public.messages for update
  using ( auth.uid() = sender_id ) with check ( auth.uid() = sender_id );
drop policy if exists "msg_delete" on public.messages;
create policy "msg_delete" on public.messages for delete
  using ( auth.uid() = sender_id );
alter table public.conversation_members add column if not exists last_read_at timestamptz;
create or replace function public.mark_conversation_read(conv uuid)
returns void language sql security definer set search_path = public as $$
  update public.conversation_members set last_read_at = now()
  where conversation_id = conv and user_id = auth.uid();
$$;
grant execute on function public.mark_conversation_read(uuid) to authenticated;
create or replace function public.unread_by_conversation()
returns table(conversation_id uuid, n int)
language sql security definer set search_path = public as $$
  select m.conversation_id, count(*)::int
  from public.messages m
  join public.conversation_members cm
    on cm.conversation_id = m.conversation_id and cm.user_id = auth.uid()
  where m.sender_id <> auth.uid()
    and (cm.last_read_at is null or m.created_at > cm.last_read_at)
  group by m.conversation_id;
$$;
grant execute on function public.unread_by_conversation() to authenticated;
notify pgrst, 'reload schema';


-- ============================================================
--  45. GAMIFICATION & RÉPUTATION (scores calculés, sans triggers)
--  Scores/badges CALCULÉS à la demande depuis les données existantes
--  (pas de compteur à maintenir). Détail dans supabase/gamification.sql.
-- ============================================================

create or replace function public.user_stats(uid uuid)
returns json language plpgsql security definer set search_path = public as $$
declare j json;
begin
  if auth.uid() is null then raise exception 'non authentifié'; end if;
  select json_build_object(
    'posts',          (select count(*) from posts    where author_id = uid and not coalesce(is_reel,false)),
    'reels',          (select count(*) from posts    where author_id = uid and coalesce(is_reel,false)),
    'comments',       (select count(*) from comments where author_id = uid),
    'likes_received', (select count(*) from likes l join posts p on p.id = l.post_id where p.author_id = uid),
    'likes_given',    (select count(*) from likes    where user_id = uid),
    'friends',        (select count(*) from friendships where status='accepted' and (requester_id = uid or addressee_id = uid)),
    'events',         (select count(*) from events   where creator_id = uid),
    'photos',         (select count(*) from album_photos where owner_id = uid),
    'member_since',   (select created_at from profiles where id = uid)
  ) into j;
  return j;
end; $$;
grant execute on function public.user_stats(uuid) to authenticated;

create or replace function public.leaderboard(period text default 'all', lim int default 20)
returns table(user_id uuid, name text, avatar text, town text, score int, posts int, comments int, likes_recv int)
language plpgsql security definer set search_path = public as $$
declare since timestamptz;
begin
  if auth.uid() is null then raise exception 'non authentifié'; end if;
  since := case when period = 'month' then date_trunc('month', now()) else '1970-01-01'::timestamptz end;
  return query
  with po as (
    select author_id as uid,
           count(*) filter (where not coalesce(is_reel,false))::int as nposts,
           count(*) filter (where     coalesce(is_reel,false))::int as nreels
    from posts where created_at >= since group by author_id
  ),
  co as (
    select author_id as uid, count(*)::int as ncomments
    from comments where created_at >= since group by author_id
  ),
  lk as (
    select p.author_id as uid, count(*)::int as nlikes
    from likes l join posts p on p.id = l.post_id
    where l.created_at >= since group by p.author_id
  ),
  ranked as (
    select pr.id as uid, pr.name as nm, pr.avatar_url as av, pr.town as tw,
      (coalesce(po.nposts,0)*5 + coalesce(po.nreels,0)*8 + coalesce(co.ncomments,0)*2 + coalesce(lk.nlikes,0))::int as sc,
      coalesce(po.nposts,0)::int as np, coalesce(co.ncomments,0)::int as nc, coalesce(lk.nlikes,0)::int as nl,
      pr.created_at as cr
    from profiles pr
    left join po on po.uid = pr.id
    left join co on co.uid = pr.id
    left join lk on lk.uid = pr.id
    where coalesce(pr.is_banned,false) = false
  )
  select uid, nm, av, tw, sc, np, nc, nl
  from ranked where sc > 0
  order by sc desc, cr asc
  limit greatest(lim,1);
end; $$;
grant execute on function public.leaderboard(text,int) to authenticated;

notify pgrst, 'reload schema';


-- ============================================================
--  46. APPELS MANQUÉS (notification) — détail dans appels-manques.sql
--  Notification au destinataire quand un appel n'est pas décroché.
--  Le message « 📞 Appel manqué » dans la conversation est inséré
--  côté client par l'appelant. Réservé aux amis. SECURITY DEFINER.
-- ============================================================
create or replace function public.log_missed_call(other uuid, video boolean default false)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or other is null or other = auth.uid() then return; end if;
  if not public.are_friends(other) then return; end if;
  insert into public.notifications (user_id, actor_id, type)
  values (other, auth.uid(), case when video then 'missed_video' else 'missed_call' end);
end; $$;
grant execute on function public.log_missed_call(uuid, boolean) to authenticated;
notify pgrst, 'reload schema';


-- ============================================================
--  47. PUBLIER EN TANT QUE PAGE — détail dans publier-en-tant-que-page.sql
--  posts.page_id = publié EN TANT QUE cette page (group_id reste NULL ->
--  apparaît dans le fil, affiché comme la page). Insertion réservée aux
--  gestionnaires de la page. Backfill des murs de page vers le fil.
-- ============================================================
alter table public.posts add column if not exists page_id uuid references public.groups(id) on delete cascade;
create index if not exists posts_page_idx on public.posts(page_id, created_at desc);

drop policy if exists "publier en son nom" on public.posts;
drop policy if exists "posts_insert" on public.posts;
create policy "posts_insert" on public.posts for insert with check (
  auth.uid() = author_id
  and ( page_id is null or public.is_group_manager(page_id) )
);

update public.posts p set page_id = p.group_id, group_id = null
  where p.group_id in (select id from public.groups where kind = 'page') and p.page_id is null;

notify pgrst, 'reload schema';


-- ============================================================
--  48. PARAMÈTRES DE PUBLICATION DES GROUPES — détail dans parametres-groupes.sql
--  post_policy ('all'|'admins'), post_approval (validation des posts).
--  La validation des ADHÉSIONS existe déjà via groups.is_private.
-- ============================================================
alter table public.groups add column if not exists post_policy   text default 'all';
alter table public.groups add column if not exists post_approval boolean default false;
alter table public.posts  add column if not exists pending boolean default false;
create index if not exists posts_group_pending_idx on public.posts(group_id, pending, created_at desc);

drop policy if exists "publier en son nom" on public.posts;
drop policy if exists "posts_insert" on public.posts;
create policy "posts_insert" on public.posts for insert with check (
  auth.uid() = author_id
  and ( page_id is null or public.is_group_manager(page_id) )
  and (
    group_id is null
    or public.is_group_manager(group_id)
    or exists (
      select 1 from public.groups g
      where g.id = group_id
        and coalesce(g.post_policy,'all') = 'all'
        and pending = coalesce(g.post_approval,false)
    )
  )
);

drop policy if exists "valider les posts du groupe" on public.posts;
create policy "valider les posts du groupe" on public.posts for update
  using ( group_id is not null and public.is_group_manager(group_id) )
  with check ( group_id is not null and public.is_group_manager(group_id) );

drop policy if exists "supprimer les posts du groupe" on public.posts;
create policy "supprimer les posts du groupe" on public.posts for delete
  using ( group_id is not null and public.is_group_manager(group_id) );

notify pgrst, 'reload schema';


-- ============================================================
--  49. AJOUT D'ADMINISTRATEUR / DE MEMBRE par un gestionnaire
--  Permet à un owner/admin d'AJOUTER une personne (comme membre ou admin)
--  à son groupe/page — en plus de « rejoindre » (auth.uid()=user_id).
-- ============================================================
drop policy if exists "gestionnaire ajoute un membre" on public.group_members;
create policy "gestionnaire ajoute un membre" on public.group_members for insert
  with check ( public.is_group_manager(group_id) and role in ('member','admin') );
notify pgrst, 'reload schema';


-- ============================================================
--  50. NOTIFICATIONS D'ACTIVITÉ DE GROUPE / PAGE — détail dans notif-activite-groupe.sql
--  Nouveau post dans un groupe rejoint / une page suivie -> notif aux
--  membres/abonnés (sauf auteur, hors pending). Moteur de ré-engagement.
-- ============================================================
create or replace function public.notify_on_group_post()
returns trigger language plpgsql security definer set search_path = public as $$
declare gid uuid; ptype text;
begin
  if coalesce(NEW.pending, false) then return NEW; end if;
  if NEW.group_id is not null then gid := NEW.group_id; ptype := 'group_post';
  elsif NEW.page_id is not null then gid := NEW.page_id; ptype := 'page_post';
  else return NEW; end if;
  insert into public.notifications (user_id, actor_id, type, post_id)
  select m.user_id, NEW.author_id, ptype, NEW.id
  from public.group_members m
  where m.group_id = gid
    and m.user_id <> NEW.author_id
    and coalesce(m.role,'member') <> 'pending';
  return NEW;
end; $$;
drop trigger if exists trg_notify_group_post on public.posts;
create trigger trg_notify_group_post after insert on public.posts
  for each row execute function public.notify_on_group_post();
notify pgrst, 'reload schema';


-- ============================================================
--  FIN. Tout est à jour.
-- ============================================================

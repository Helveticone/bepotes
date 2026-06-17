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
  pid := case when TG_TABLE_NAME = 'comments' then NEW.post_id else NEW.id end;
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
--  FIN. Tout est à jour.
-- ============================================================

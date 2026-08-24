-- ============================================================
--  BEPOTES — Schéma Supabase complet
--  À coller dans : Supabase > SQL Editor > New query > Run
--  Couvre : profils, abonnements, publications, commentaires,
--  likes, événements, messagerie, notifications, groupes,
--  signalements (modération).
--  Sécurité : Row Level Security (RLS) activée sur tout.
-- ============================================================

-- ============================================================
--  0. EXTENSIONS
-- ============================================================
create extension if not exists "pgcrypto";   -- gen_random_uuid()

-- ============================================================
--  1. PROFILS
--  Étend la table auth.users gérée par Supabase Auth.
--  Un profil est créé automatiquement à l'inscription (trigger plus bas).
-- ============================================================
create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  name        text not null,
  town        text,
  bio         text default '',
  avatar_url  text,
  cover_url   text,
  is_pro      boolean default false,        -- compte commerce/asso
  created_at  timestamptz default now()
);

alter table public.profiles enable row level security;

-- Tout le monde (connecté) peut voir les profils
create policy "profils visibles par les membres"
  on public.profiles for select
  using ( auth.role() = 'authenticated' );

-- Chacun ne modifie que SON profil
create policy "modifier son propre profil"
  on public.profiles for update
  using ( auth.uid() = id );

-- Création du profil à l'inscription (par le trigger, voir §11)
create policy "créer son propre profil"
  on public.profiles for insert
  with check ( auth.uid() = id );

-- ============================================================
--  2. ABONNEMENTS (graphe social asymétrique, façon Instagram)
--  follower suit followee.
-- ============================================================
create table public.follows (
  follower_id  uuid references public.profiles(id) on delete cascade,
  followee_id  uuid references public.profiles(id) on delete cascade,
  created_at   timestamptz default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)         -- on ne se suit pas soi-même
);

alter table public.follows enable row level security;

create policy "abonnements visibles"
  on public.follows for select
  using ( auth.role() = 'authenticated' );

create policy "s'abonner soi-même"
  on public.follows for insert
  with check ( auth.uid() = follower_id );

create policy "se désabonner soi-même"
  on public.follows for delete
  using ( auth.uid() = follower_id );

-- ============================================================
--  3. PUBLICATIONS
-- ============================================================
create table public.posts (
  id          uuid primary key default gen_random_uuid(),
  author_id   uuid references public.profiles(id) on delete cascade not null,
  text        text not null,
  tag         text default 'Général',
  image_url   text,
  group_id    uuid,                          -- null = fil public ; sinon publication de groupe
  created_at  timestamptz default now()
);

alter table public.posts enable row level security;
create index posts_author_idx  on public.posts(author_id);
create index posts_created_idx on public.posts(created_at desc);
create index posts_group_idx   on public.posts(group_id);

create policy "publications visibles par les membres"
  on public.posts for select
  using ( auth.role() = 'authenticated' );

create policy "publier en son nom"
  on public.posts for insert
  with check ( auth.uid() = author_id );

create policy "modifier ses publications"
  on public.posts for update
  using ( auth.uid() = author_id );

create policy "supprimer ses publications"
  on public.posts for delete
  using ( auth.uid() = author_id );

-- ============================================================
--  4. COMMENTAIRES
-- ============================================================
create table public.comments (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid references public.posts(id) on delete cascade not null,
  author_id   uuid references public.profiles(id) on delete cascade not null,
  text        text not null,
  created_at  timestamptz default now()
);

alter table public.comments enable row level security;
create index comments_post_idx on public.comments(post_id);

create policy "commentaires visibles"
  on public.comments for select
  using ( auth.role() = 'authenticated' );

create policy "commenter en son nom"
  on public.comments for insert
  with check ( auth.uid() = author_id );

create policy "supprimer ses commentaires"
  on public.comments for delete
  using ( auth.uid() = author_id );

-- ============================================================
--  5. LIKES (j'aime)
--  Une ligne par (post, utilisateur) => un seul like possible.
-- ============================================================
create table public.likes (
  post_id     uuid references public.posts(id) on delete cascade,
  user_id     uuid references public.profiles(id) on delete cascade,
  created_at  timestamptz default now(),
  primary key (post_id, user_id)
);

alter table public.likes enable row level security;

create policy "likes visibles"
  on public.likes for select
  using ( auth.role() = 'authenticated' );

create policy "aimer en son nom"
  on public.likes for insert
  with check ( auth.uid() = user_id );

create policy "retirer son like"
  on public.likes for delete
  using ( auth.uid() = user_id );

-- ============================================================
--  6. ÉVÉNEMENTS + PARTICIPATIONS
-- ============================================================
create table public.events (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  town         text,
  starts_at    timestamptz,
  description  text,
  cover_url    text,
  creator_id   uuid references public.profiles(id) on delete set null,
  created_at   timestamptz default now()
);

create table public.event_attendees (
  event_id     uuid references public.events(id) on delete cascade,
  user_id      uuid references public.profiles(id) on delete cascade,
  created_at   timestamptz default now(),
  primary key (event_id, user_id)
);

alter table public.events           enable row level security;
alter table public.event_attendees  enable row level security;

create policy "événements visibles"
  on public.events for select using ( auth.role() = 'authenticated' );
create policy "créer un événement"
  on public.events for insert with check ( auth.uid() = creator_id );
create policy "modifier son événement"
  on public.events for update using ( auth.uid() = creator_id );
create policy "supprimer son événement"
  on public.events for delete using ( auth.uid() = creator_id );

create policy "participations visibles"
  on public.event_attendees for select using ( auth.role() = 'authenticated' );
create policy "participer soi-même"
  on public.event_attendees for insert with check ( auth.uid() = user_id );
create policy "annuler sa participation"
  on public.event_attendees for delete using ( auth.uid() = user_id );

-- ============================================================
--  7. GROUPES / COMMUNAUTÉS + MEMBRES
-- ============================================================
create table public.groups (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  description  text,
  town         text,
  cover_url    text,
  owner_id     uuid references public.profiles(id) on delete set null,
  created_at   timestamptz default now()
);

create table public.group_members (
  group_id     uuid references public.groups(id) on delete cascade,
  user_id      uuid references public.profiles(id) on delete cascade,
  role         text default 'member',        -- 'owner' | 'admin' | 'member'
  created_at   timestamptz default now(),
  primary key (group_id, user_id)
);

alter table public.groups         enable row level security;
alter table public.group_members  enable row level security;

create policy "groupes visibles"
  on public.groups for select using ( auth.role() = 'authenticated' );
create policy "créer un groupe"
  on public.groups for insert with check ( auth.uid() = owner_id );
create policy "modifier son groupe"
  on public.groups for update using ( auth.uid() = owner_id );

create policy "membres visibles"
  on public.group_members for select using ( auth.role() = 'authenticated' );
create policy "rejoindre un groupe"
  on public.group_members for insert with check ( auth.uid() = user_id );
create policy "quitter un groupe"
  on public.group_members for delete using ( auth.uid() = user_id );

-- ============================================================
--  8. MESSAGERIE (conversations + messages)
--  Modèle simple : une conversation a N participants, N messages.
-- ============================================================
create table public.conversations (
  id           uuid primary key default gen_random_uuid(),
  is_group     boolean default false,
  title        text,                          -- pour les conversations de groupe
  created_at   timestamptz default now()
);

create table public.conversation_members (
  conversation_id uuid references public.conversations(id) on delete cascade,
  user_id         uuid references public.profiles(id) on delete cascade,
  created_at      timestamptz default now(),
  primary key (conversation_id, user_id)
);

create table public.messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid references public.conversations(id) on delete cascade not null,
  sender_id       uuid references public.profiles(id) on delete cascade not null,
  text            text not null,
  created_at      timestamptz default now()
);
create index messages_conv_idx on public.messages(conversation_id, created_at);

alter table public.conversations         enable row level security;
alter table public.conversation_members  enable row level security;
alter table public.messages              enable row level security;

-- Fonction utilitaire : l'utilisateur est-il membre de la conversation ?
create or replace function public.is_conversation_member(conv uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.conversation_members
    where conversation_id = conv and user_id = auth.uid()
  );
$$;

-- On ne voit que les conversations dont on est membre
create policy "voir ses conversations"
  on public.conversations for select
  using ( public.is_conversation_member(id) );
create policy "créer une conversation"
  on public.conversations for insert
  with check ( auth.role() = 'authenticated' );

create policy "voir les membres de ses conversations"
  on public.conversation_members for select
  using ( public.is_conversation_member(conversation_id) );
create policy "s'ajouter / ajouter à une conversation"
  on public.conversation_members for insert
  with check ( auth.role() = 'authenticated' );

-- On ne lit/écrit que les messages de ses conversations
create policy "lire les messages de ses conversations"
  on public.messages for select
  using ( public.is_conversation_member(conversation_id) );
create policy "envoyer un message"
  on public.messages for insert
  with check ( auth.uid() = sender_id and public.is_conversation_member(conversation_id) );

-- ============================================================
--  9. NOTIFICATIONS
--  Créées par des triggers (like, commentaire, abonnement, message).
-- ============================================================
create table public.notifications (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid references public.profiles(id) on delete cascade not null, -- destinataire
  actor_id     uuid references public.profiles(id) on delete cascade,          -- qui a déclenché
  type         text not null,                  -- 'like' | 'comment' | 'follow' | 'message'
  post_id      uuid references public.posts(id) on delete cascade,
  read         boolean default false,
  created_at   timestamptz default now()
);
create index notifications_user_idx on public.notifications(user_id, created_at desc);

alter table public.notifications enable row level security;

create policy "voir ses notifications"
  on public.notifications for select
  using ( auth.uid() = user_id );
create policy "marquer ses notifications comme lues"
  on public.notifications for update
  using ( auth.uid() = user_id );

-- ============================================================
--  10. SIGNALEMENTS (modération)
-- ============================================================
create table public.reports (
  id            uuid primary key default gen_random_uuid(),
  reporter_id   uuid references public.profiles(id) on delete set null,
  post_id       uuid references public.posts(id) on delete cascade,
  reported_user uuid references public.profiles(id) on delete cascade,
  reason        text,
  status        text default 'open',          -- 'open' | 'reviewed' | 'dismissed'
  created_at    timestamptz default now()
);

alter table public.reports enable row level security;

-- Un membre peut créer un signalement et voir les siens
create policy "signaler"
  on public.reports for insert
  with check ( auth.uid() = reporter_id );
create policy "voir ses signalements"
  on public.reports for select
  using ( auth.uid() = reporter_id );
-- (La modération admin se gère via la service_role key, qui contourne RLS.)

-- ============================================================
--  11. TRIGGER : créer le profil à l'inscription
--  Quand un utilisateur s'inscrit (auth.users), on crée son profil.
--  Le nom et la commune sont passés dans les "métadonnées" à l'inscription.
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, name, town)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'name', 'Nouveau membre'),
    new.raw_user_meta_data ->> 'town'
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
--  12. TRIGGERS : notifications automatiques
-- ============================================================
-- Like -> notifier l'auteur du post
create or replace function public.notify_on_like()
returns trigger language plpgsql security definer set search_path = public as $$
declare author uuid;
begin
  select author_id into author from public.posts where id = new.post_id;
  if author is not null and author <> new.user_id then
    insert into public.notifications (user_id, actor_id, type, post_id)
    values (author, new.user_id, 'like', new.post_id);
  end if;
  return new;
end; $$;

drop trigger if exists trg_notify_like on public.likes;
create trigger trg_notify_like
  after insert on public.likes
  for each row execute function public.notify_on_like();

-- Commentaire -> notifier l'auteur du post
create or replace function public.notify_on_comment()
returns trigger language plpgsql security definer set search_path = public as $$
declare author uuid;
begin
  select author_id into author from public.posts where id = new.post_id;
  if author is not null and author <> new.author_id then
    insert into public.notifications (user_id, actor_id, type, post_id)
    values (author, new.author_id, 'comment', new.post_id);
  end if;
  return new;
end; $$;

drop trigger if exists trg_notify_comment on public.comments;
create trigger trg_notify_comment
  after insert on public.comments
  for each row execute function public.notify_on_comment();

-- Abonnement -> notifier la personne suivie
create or replace function public.notify_on_follow()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (user_id, actor_id, type)
  values (new.followee_id, new.follower_id, 'follow');
  return new;
end; $$;

drop trigger if exists trg_notify_follow on public.follows;
create trigger trg_notify_follow
  after insert on public.follows
  for each row execute function public.notify_on_follow();

-- ============================================================
--  13. VUE PRATIQUE : compteurs de posts (likes + commentaires)
--  Évite de compter côté client.
-- ============================================================
create or replace view public.posts_with_counts as
select
  p.*,
  (select count(*) from public.likes    l where l.post_id = p.id) as like_count,
  (select count(*) from public.comments c where c.post_id = p.id) as comment_count
from public.posts p;

-- ============================================================
--  FIN DU SCHÉMA
--  Étapes suivantes côté Supabase (interface, pas SQL) :
--   1) Storage : créer 3 buckets PUBLICS -> "avatars", "covers", "posts"
--   2) Realtime : activer la réplication sur les tables "messages"
--      et "notifications" (Database > Replication) pour le temps réel.
--   3) Auth : garder "Email" activé (Authentication > Providers).
-- ============================================================

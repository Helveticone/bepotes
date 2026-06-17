-- ============================================================
--  JURAPOTES — Fiabiliser TOUTES les policies de lecture
--  À exécuter dans Supabase > SQL Editor.
--  Remplace les "auth.role() = 'authenticated'" (fragiles avec
--  les nouvelles clés JWT) par "auth.uid() is not null" (fiable).
--  Couvre : profils, follows, posts, comments, likes, events,
--  event_attendees, groups, group_members.
-- ============================================================

-- PROFILES
drop policy if exists "profils visibles par les membres" on public.profiles;
drop policy if exists "profiles_select" on public.profiles;
create policy "profiles_select" on public.profiles for select using ( auth.uid() is not null );

-- FOLLOWS
drop policy if exists "abonnements visibles" on public.follows;
drop policy if exists "follows_select" on public.follows;
create policy "follows_select" on public.follows for select using ( auth.uid() is not null );

-- POSTS
drop policy if exists "publications visibles par les membres" on public.posts;
drop policy if exists "posts_select" on public.posts;
create policy "posts_select" on public.posts for select using ( auth.uid() is not null );

-- COMMENTS
drop policy if exists "commentaires visibles" on public.comments;
drop policy if exists "comments_select" on public.comments;
create policy "comments_select" on public.comments for select using ( auth.uid() is not null );

-- LIKES
drop policy if exists "likes visibles" on public.likes;
drop policy if exists "likes_select" on public.likes;
create policy "likes_select" on public.likes for select using ( auth.uid() is not null );

-- EVENTS
drop policy if exists "événements visibles" on public.events;
drop policy if exists "events_select" on public.events;
create policy "events_select" on public.events for select using ( auth.uid() is not null );

-- EVENT ATTENDEES
drop policy if exists "participations visibles" on public.event_attendees;
drop policy if exists "event_attendees_select" on public.event_attendees;
create policy "event_attendees_select" on public.event_attendees for select using ( auth.uid() is not null );

-- GROUPS
drop policy if exists "groupes visibles" on public.groups;
drop policy if exists "groups_select" on public.groups;
create policy "groups_select" on public.groups for select using ( auth.uid() is not null );

-- GROUP MEMBERS
drop policy if exists "membres visibles" on public.group_members;
drop policy if exists "group_members_select" on public.group_members;
create policy "group_members_select" on public.group_members for select using ( auth.uid() is not null );

-- (Les policies d'écriture utilisaient déjà auth.uid(), pas besoin d'y toucher.)

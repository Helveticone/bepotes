-- ============================================================
--  50. NOTIFICATIONS D'ACTIVITÉ DE GROUPE / PAGE
--  Quand quelqu'un publie dans un groupe (group_id) ou en tant que page
--  (page_id), tous les membres / abonnés (sauf l'auteur, hors « pending »)
--  reçoivent une notification. Moteur de ré-engagement.
--  - type 'group_post' (groupe) | 'page_post' (page)
--  - on ne notifie PAS les posts en attente de validation (pending=true)
-- ============================================================
create or replace function public.notify_on_group_post()
returns trigger language plpgsql security definer set search_path = public as $$
declare gid uuid; ptype text;
begin
  if coalesce(NEW.pending, false) then return NEW; end if;   -- post à valider : pas de notif tant que non approuvé
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

-- ============================================================
--  JURAPOTES — @mentions (notifier les personnes mentionnées)
--  À exécuter dans Supabase > SQL Editor (après TOUT-LE-SQL.sql).
--  Sûr à ré-exécuter (idempotent).
--  ------------------------------------------------------------
--  Le texte stocke les mentions sous la forme @[Nom](uuid).
--  À l'insertion d'une publication ou d'un commentaire, on crée
--  une notification de type 'mention' pour chaque personne citée.
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
    begin
      uid := m.id::uuid;
    exception when others then uid := null; end;
    if uid is not null and uid <> actor then
      insert into public.notifications (user_id, actor_id, type, post_id)
      values (uid, actor, 'mention', pid);
    end if;
  end loop;
  return NEW;
end; $$;

drop trigger if exists trg_notify_mention_post on public.posts;
create trigger trg_notify_mention_post
  after insert on public.posts
  for each row execute function public.notify_on_mention();

drop trigger if exists trg_notify_mention_comment on public.comments;
create trigger trg_notify_mention_comment
  after insert on public.comments
  for each row execute function public.notify_on_mention();

-- ============================================================
--  TAGS DE PERSONNES SUR LES PHOTOS
--  L'auteur d'une publication identifie des amis ; ceux-ci sont notifiés.
--  (Idempotent ; à relancer dans Supabase SQL Editor.)
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

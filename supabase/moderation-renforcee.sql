-- ============================================================
--  MODÉRATION RENFORCÉE : mots interdits + file d'attente
--  Les posts/commentaires contenant un mot interdit sont auto-signalés
--  dans une file d'attente (mod_queue) pour examen admin (sans blocage).
--  (Idempotent ; à relancer dans Supabase SQL Editor.)
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

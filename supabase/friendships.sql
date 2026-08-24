-- ============================================================
--  BEPOTES — Amitiés (demandes d'ami réciproques)
--  À exécuter dans Supabase > SQL Editor APRÈS le schema.sql.
--  Complète le système d'abonnements (follows) existant :
--   - follows  = suivre (unilatéral, façon Instagram)  [déjà en place]
--   - friendships = être amis (réciproque, façon Facebook) [ici]
-- ============================================================

create table if not exists public.friendships (
  id           uuid primary key default gen_random_uuid(),
  requester_id uuid references public.profiles(id) on delete cascade not null, -- qui demande
  addressee_id uuid references public.profiles(id) on delete cascade not null, -- qui reçoit
  status       text default 'pending',  -- 'pending' | 'accepted'
  created_at   timestamptz default now(),
  unique (requester_id, addressee_id),
  check (requester_id <> addressee_id)
);

create index if not exists friendships_addressee_idx on public.friendships(addressee_id, status);
create index if not exists friendships_requester_idx on public.friendships(requester_id, status);

alter table public.friendships enable row level security;

-- Voir les amitiés qui me concernent (envoyées ou reçues)
create policy "voir mes amitiés"
  on public.friendships for select
  using ( auth.uid() = requester_id or auth.uid() = addressee_id );

-- Envoyer une demande (je suis forcément le demandeur)
create policy "envoyer une demande d'ami"
  on public.friendships for insert
  with check ( auth.uid() = requester_id );

-- Accepter / mettre à jour : seulement le destinataire peut accepter,
-- et chacun des deux peut supprimer (retirer ami / annuler / refuser).
create policy "répondre à une demande d'ami"
  on public.friendships for update
  using ( auth.uid() = addressee_id or auth.uid() = requester_id );

create policy "supprimer une amitié"
  on public.friendships for delete
  using ( auth.uid() = requester_id or auth.uid() = addressee_id );

-- Notification : quand une demande d'ami est envoyée OU acceptée
create or replace function public.notify_on_friendship()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (TG_OP = 'INSERT') then
    -- nouvelle demande -> notifier le destinataire
    insert into public.notifications (user_id, actor_id, type)
    values (new.addressee_id, new.requester_id, 'friend_request');
  elsif (TG_OP = 'UPDATE' and new.status = 'accepted' and old.status = 'pending') then
    -- demande acceptée -> notifier le demandeur
    insert into public.notifications (user_id, actor_id, type)
    values (new.requester_id, new.addressee_id, 'friend_accept');
  end if;
  return new;
end; $$;

drop trigger if exists trg_notify_friendship on public.friendships;
create trigger trg_notify_friendship
  after insert or update on public.friendships
  for each row execute function public.notify_on_friendship();

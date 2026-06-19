-- ============================================================
--  46. APPELS MANQUÉS (notification)
--  Un appel non décroché (sans réponse / refusé / annulé avant
--  connexion) crée une notification pour le destinataire. Le message
--  « 📞 Appel manqué » dans la conversation est, lui, inséré côté client
--  par l'appelant (RLS messages standard). Réservé aux amis (cohérent
--  avec la messagerie). SECURITY DEFINER car aucun insert client direct
--  n'est autorisé sur la table notifications.
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

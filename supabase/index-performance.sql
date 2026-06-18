-- ============================================================
--  INDEX DE PERFORMANCE (montée en charge) — section 39
--  Couvre les colonnes les plus filtrées/triées des requêtes fréquentes.
--  Idempotent (create index if not exists). À relancer dans Supabase SQL Editor.
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

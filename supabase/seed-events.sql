-- ============================================================
--  BEPOTES — Quelques événements de démarrage (optionnel)
--  À exécuter une fois si tu veux que la page Événements ne soit
--  pas vide au lancement. Tu peux les supprimer plus tard.
-- ============================================================
insert into public.events (title, town, starts_at) values
  ('Marché du terroir',                 'Porrentruy',    now() + interval '5 days'),
  ('Concert au Café du Soleil',         'Saignelégier',  now() + interval '11 days'),
  ('Vide-grenier de la vieille ville',  'Delémont',      now() + interval '19 days'),
  ('Rando nocturne aux étangs',         'Le Noirmont',   now() + interval '26 days');

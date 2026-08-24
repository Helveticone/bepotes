/* Communes de Belgique francophone — Région wallonne (262) + Région de Bruxelles-Capitale (19) = 281.
   Source : https://github.com/vandenbroucke/belgian_municipalities — data/2020/root.json
   Champ « municipality_FR », filtré sur « region_FR » (Région flamande exclue), trié A→Z (locale fr), dédupliqué.
   FICHIER GÉNÉRÉ — ne pas éditer à la main : régénérer depuis la source.
   Usage : charger AVANT app.supabase.js ; expose window.JP_COMMUNES (et JP.COMMUNES si JP est déjà chargé). */
(function(){
  var COMMUNES = [
    'Aiseau-Presles','Amay','Amblève','Andenne','Anderlecht','Anderlues','Anhée','Ans',
    'Anthisnes','Antoing','Arlon','Assesse','Ath','Attert','Aubange','Aubel','Auderghem','Awans',
    'Aywaille','Baelen','Bassenge','Bastogne','Beaumont','Beauraing','Beauvechain','Beloeil',
    'Berchem-Sainte-Agathe','Berloz','Bernissart','Bertogne','Bertrix','Beyne-Heusay','Bièvre',
    'Binche','Blégny','Bouillon','Boussu','Braine-l’Alleud','Braine-le-Château','Braine-le-Comte',
    'Braives','Brugelette','Brunehaut','Bruxelles','Bullange','Burdinne','Burg-Reuland',
    'Butgenbach','Celles','Cerfontaine','Chapelle-lez-Herlaimont','Charleroi','Chastre',
    'Châtelet','Chaudfontaine','Chaumont-Gistoux','Chièvres','Chimay','Chiny','Ciney','Clavier',
    'Colfontaine','Comblain-au-Pont','Comines-Warneton','Courcelles','Court-Saint-Etienne',
    'Couvin','Crisnée','Dalhem','Daverdisse','Dinant','Dison','Doische','Donceel','Dour','Durbuy',
    'Ecaussinnes','Eghezée','Ellezelles','Enghien','Engis','Erezée','Erquelinnes','Esneux',
    'Estaimpuis','Estinnes','Etalle','Etterbeek','Eupen','Evere','Faimes','Farciennes',
    'Fauvillers','Fernelmont','Ferrières','Fexhe-le-Haut-Clocher','Flémalle','Fléron','Fleurus',
    'Flobecq','Floreffe','Florennes','Florenville','Fontaine-l’Evêque','Forest','Fosses-la-Ville',
    'Frameries','Frasnes-lez-Anvaing','Froidchapelle','Ganshoren','Gedinne','Geer','Gembloux',
    'Genappe','Gerpinnes','Gesves','Gouvy','Grâce-Hollogne','Grez-Doiceau','Habay',
    'Ham-sur-Heure-Nalinnes','Hamoir','Hamois','Hannut','Hastière','Havelange','Hélécine',
    'Hensies','Herbeumont','Héron','Herstal','Herve','Honnelles','Hotton','Houffalize','Houyet',
    'Huy','Incourt','Ittre','Ixelles','Jalhay','Jemeppe-sur-Sambre','Jette','Jodoigne','Juprelle',
    'Jurbise','Koekelberg','La Bruyère','La Calamine','La Hulpe','La Louvière',
    'La Roche-en-Ardenne','Lasne','Le Roeulx','Léglise','Lens','Les Bons Villers','Lessines',
    'Leuze-en-Hainaut','Libin','Libramont-Chevigny','Liège','Lierneux','Limbourg','Lincent',
    'Lobbes','Lontzen','Malmedy','Manage','Manhay','Marche-en-Famenne','Marchin','Martelange',
    'Meix-devant-Virton','Merbes-le-Château','Messancy','Mettet','Modave','Molenbeek-Saint-Jean',
    'Momignies','Mons','Mont-de-l’Enclus','Mont-Saint-Guibert','Montigny-le-Tilleul','Morlanwelz',
    'Mouscron','Musson','Namur','Nandrin','Nassogne','Neufchâteau','Neupré','Nivelles','Ohey',
    'Olne','Onhaye','Oreye','Orp-Jauche','Ottignies-Louvain-la-Neuve','Ouffet','Oupeye',
    'Paliseul','Pecq','Pepinster','Péruwelz','Perwez','Philippeville','Plombières',
    'Pont-à-Celles','Profondeville','Quaregnon','Quévy','Quiévrain','Raeren','Ramillies','Rebecq',
    'Remicourt','Rendeux','Rixensart','Rochefort','Rouvroy','Rumes','Saint-Georges-sur-Meuse',
    'Saint-Ghislain','Saint-Gilles','Saint-Hubert','Saint-Josse-ten-Noode','Saint-Léger',
    'Saint-Nicolas','Saint-Vith','Sainte-Ode','Sambreville','Schaerbeek','Seneffe','Seraing',
    'Silly','Sivry-Rance','Soignies','Sombreffe','Somme-Leuze','Soumagne','Spa','Sprimont',
    'Stavelot','Stoumont','Tellin','Tenneville','Theux','Thimister-Clermont','Thuin','Tinlot',
    'Tintigny','Tournai','Trois-Ponts','Trooz','Tubize','Uccle','Vaux-sur-Sûre','Verlaine',
    'Verviers','Vielsalm','Villers-la-Ville','Villers-Le-Bouillet','Viroinval','Virton','Visé',
    'Vresse-sur-Semois','Waimes','Walcourt','Walhain','Wanze','Waremme','Wasseiges','Waterloo',
    'Watermael-Boitsfort','Wavre','Welkenraedt','Wellin','Woluwe-Saint-Lambert',
    'Woluwe-Saint-Pierre','Yvoir'
  ];
  window.JP_COMMUNES = COMMUNES;
  if (window.JP) window.JP.COMMUNES = COMMUNES;
})();


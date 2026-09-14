# Validation de la candidate 1.0.1-rc.3

Date : 14 septembre 2026. Statut : preversion publiable, validation stable incomplete.

## Verifications reussies

- 32 tests du moteur PowerShell, sans modification de la configuration Windows.
- 4 scenarios du lanceur BAT dans un chemin contenant espaces, esperluette et apostrophe.
- 51 assertions navigateur dans Chrome, avec navigation clavier, affichage mobile simule, recherche du guide, animations reduites et ressources locales.
- Rapport reel en session standard Windows 11 : cinq mesures disponibles, score 93/100.
- Rapport planifie reel Windows 11 : execution terminee avec le code 0, rapport produit, puis tache temporaire supprimee.
- Manifeste JSON lisible par PowerShell et archive accompagnee de son empreinte SHA-256.

Les preuves des deux essais Windows 11 sont detaillees dans `RESULTATS_RC2.md`. Elles restent valables, car la rc.3 ne change ni le calcul du score ni la tache planifiee.

## Corrections propres a la rc.3

- Un plan d alimentation absent est duplique sans imposer le GUID reserve du modele ; Windows choisit le nouvel identifiant, qui est ensuite extrait et verifie avant activation.
- L assistant Windows Update n enchaine plus DISM et SFC lorsque la reparation des composants Update a echoue ou a ete refusee.
- Le profil Confidentialite n applique plus Windows Search lorsque la premiere etape a echoue ou a ete refusee.
- Le test navigateur restitue maintenant le journal Chrome en cas d arret du processus.
- La construction utilise un ordre et un horodatage ZIP fixes, normalise les fins de ligne et evite la compression variable : deux builds consecutifs produisent la meme empreinte SHA-256.

## Blocages avant version stable

- Executer les actions de modification et leur restauration dans une VM Windows 10 et une VM Windows 11 avec instantanes.
- Verifier au minimum une session non administrateur, un refus UAC et une interface Windows en anglais.
- Faire la recette tactile sur un telephone reel, la lecture du QR code sur Android et iPhone, puis un parcours avec lecteur d ecran.
- Consigner chaque resultat dans la matrice `VALIDATION_WINDOWS.md` et corriger tout echec avant de retirer la mention de preversion.

La rc.3 peut rester disponible publiquement pour recueillir des retours. Elle ne doit pas encore etre etiquetee comme version stable.

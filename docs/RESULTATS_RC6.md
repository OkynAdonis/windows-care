# Validation de la candidate 1.0.1-rc.6

Date : 15 septembre 2026. Statut : preversion publique, validation stable incomplete.

## Explication avant execution

Chaque choix de 1 a 29 affiche maintenant une fiche avant de lancer sa fonction :

- nom clair de l action ;
- etapes qui seront executees ;
- impact ou absence d impact sur Windows ;
- resultat attendu et emplacement du rapport lorsqu il existe.

Cette fiche ne remplace pas la securite existante. Une action sensible demande toujours sa confirmation O/N apres l explication, et une mutation reste bloquee sans elevation ou en mode simulation.

## Verifications

- 38 tests du moteur, dont la presence des quatre informations pour chacune des 29 actions ;
- 4 scenarios du lanceur BAT ;
- 52 assertions navigateur ;
- loaders et progressions de la rc.5 conserves ;
- archive reproductible, manifeste et SHA-256 concordants.

Les validations reelles des diagnostics restent consignees dans `RESULTATS_RC4.md`. Les blocages de la version stable restent decrits dans `VALIDATION_WINDOWS.md`.

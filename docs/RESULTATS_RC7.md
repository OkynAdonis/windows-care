# Validation de la candidate 1.0.1-rc.7

Date : 15 septembre 2026. Statut : candidate locale, validation Windows reelle incomplete.

## Centre de reparation des applications

Le choix 30 ouvre un sous-menu WinGet qui permet de :

- verifier la version de WinGet et ses sources ;
- afficher les mises a jour disponibles sans modifier les applications ;
- mettre a jour une application choisie par son identifiant exact ;
- lancer la reparation declaree par une application compatible ;
- exporter un inventaire JSON horodate dans le dossier de donnees.

Les mises a jour et reparations demandent une confirmation, utilisent `--exact` et ne lancent jamais une mise a jour globale. Le mode simulation bloque leur execution. L absence de WinGet renvoie vers App Installer sans interrompre Windows Care.

## Verifications automatisees

- 41 tests du moteur, dont ciblage exact, blocage en simulation et absence de WinGet ;
- 4 scenarios du lanceur BAT ;
- 52 assertions navigateur avec les 30 actions ;
- build complet reussi et presence de `Apps.ps1` dans le ZIP.

## Verification restante

La commande WinGet reelle doit etre testee en VM Windows 10 et 11 avec plusieurs versions d App Installer. Tester au moins une application reparable et une application sans commande de reparation. Aucun package n a ete modifie pendant les tests automatises.

La recherche ulterieure a aussi identifie le refus WinGet des reparations de packages utilisateur depuis une console administrateur. Le lanceur rc.9 ajoute `-StandardUser` et traduit les principaux codes de reparation en messages explicites.

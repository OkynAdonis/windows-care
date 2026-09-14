# Validation de la candidate 1.0.1-rc.5

Date : 15 septembre 2026. Statut : preversion publique, validation stable incomplete.

## Guidage des operations longues

- Les programmes Windows lances par Windows Care affichent un indicateur indetermine apres 300 ms avec le temps ecoule. Cela couvre notamment DISM, SFC, `powercfg`, `netsh` et `ipconfig`.
- Le nettoyage affiche le dossier traite puis le passage a la corbeille.
- La reparation Windows Update affiche la lecture, l arret des services, la conservation des caches et le redemarrage des services.
- Le dossier de support affiche les phases d inventaire, d analyse et d ecriture.
- Toutes les progressions internes sont fermees apres succes ou erreur afin de ne pas laisser une barre bloquee dans la console.
- Le site affiche un loader dans le bouton pendant l etat de telechargement ; avec la preference de mouvement reduit, il reste visible sans rotation.

## Verifications

- 37 tests du moteur PowerShell, dont une vraie commande lente controlant l ouverture et la fermeture de la progression ;
- 4 scenarios du lanceur BAT ;
- 52 assertions navigateur, dont la presence du loader ;
- archive reproductible, manifeste JSON et SHA-256 concordants.

Les diagnostics reels de la rc.4 restent valables, car la rc.5 ajoute uniquement le retour visuel et ne change pas les donnees collectees. Les blocages de validation stable restent ceux de `VALIDATION_WINDOWS.md`.

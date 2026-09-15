# Validation de la candidate 1.0.1-rc.9

Date : 15 septembre 2026. Statut : candidate locale, validation Windows reelle incomplete.

## Nouveaux centres

- Diagnostic Windows progressif : DISM CheckHealth, DISM ScanHealth, SFC VerifyOnly et CHKDSK Scan avant toute proposition de reparation.
- Diagnostic reseau avance : couches, configuration IP, routes, proxys, latence, DNS et interfaces physiques ou virtuelles.
- Microsoft Sysinternals : verification, installation WinGet exacte et lancement confirme d Autoruns, Process Explorer, TCPView, RAMMap ou Sigcheck.
- Premiers secours : parcours PC lent, Windows instable, reseau et securite, avec diagnostic avant correction.

## Principes verifies dans le code

- les sous-menus reviennent tous au menu principal avec le choix 0 ;
- aucune reparation Windows ou reinitialisation reseau n est declenchee par un diagnostic ;
- chaque installation Sysinternals cible un identifiant exact et demande confirmation ;
- les parcours de premiers secours n executent que des diagnostics et orientent vers les centres specialises.

## Verification restante

Les commandes DISM, SFC, CHKDSK, les configurations reseau variees et les installations Sysinternals doivent etre testees dans les VM Windows 10 et 11. Les tests automatises ne remplacent pas ces essais.

## Verifications automatisees

- 47 tests du moteur ;
- 5 scenarios du lanceur BAT, dont le lancement volontaire sans elevation ;
- 54 assertions navigateur, dont l icone Windows Care sur les deux pages ;
- build rc.9 reussi avec les quatre nouveaux modules dans le ZIP.

# Validation de la candidate 1.0.1-rc.2

Date : 14 septembre 2026. Statut : preversion, pas une validation complete Windows 10/11.

## Essais effectues

| Essai | Nature | Resultat |
|---|---|---|
| Moteur PowerShell | 29 scenarios automatises, modifications systeme simulees | Reussite |
| Lanceur BAT | 4 executions reelles avec moteur factice, chemins complexes, simulation et codes retour | Reussite |
| Site Chrome | 35 assertions : recherche, telechargements, absence de JavaScript, focus, mouvement et largeurs 320/360/768/1280 px | Reussite |
| Rapport Windows 11 Pro build 26200 | Diagnostic reel, session standard, dossier de donnees explicite | Rapport genere, 5/5 mesures disponibles |
| Rapport planifie Windows 11 Pro build 26200 | Tache elevee temporaire, compte connecte, diagnostic reel | Rapport genere, code retour 0, tache supprimee |

Le premier essai de planification est reste en attente sans rapport. La correction autorise le diagnostic sur batterie et attend un etat termine, sans confondre un code initial avec un succes d execution.

Les preuves locales (non versionnees) sont dans `data/validation-win11` et `data/validation-scheduled-win11`. Le score observe sur un seul poste ne constitue pas un resultat de compatibilite generale.

## Corrections et couverture

- Mesures indisponibles exclues du score, couverture explicite, seuil minimal de trois mesures, antivirus tiers non certifie.
- Rapports avec recommandations, donnees echappees et noms uniques.
- Validation complete du contenu des sauvegardes avant la premiere ecriture : categories, registre, services, taches, familles DNS et GUID.
- Refus central des actions de modification en session standard ; diagnostics et simulation disponibles.
- Dossier de donnees explicite ou repli annonce vers LocalAppData ; dossier transmis a la tache planifiee.
- Signalement structure des anomalies via le formulaire GitHub, sans transmission automatique de journaux.

## Non valides : prerequisites de la version stable

- Aucun gestionnaire de VM Hyper-V, VirtualBox ou VMware detecte sur le poste. Aucune VM Windows 10/11 ni image systeme fournie pendant ce lot.
- Aucune action de nettoyage, DNS, confidentialite, DISM/SFC ou reparation Windows Update appliquee au poste principal. Leurs restaurations ont ete testees avec des simulations, pas dans des machines virtuelles.
- Aucun telephone physique ni lecteur d ecran accessible. Les essais navigateur utilisent Chrome sur ordinateur avec differentes largeurs et controles de focus ; cela ne vaut pas une recette sur appareil reel.
- Les variantes Windows 10, langues autres que le francais, politiques d entreprise, antivirus tiers reels et refus UAC interactif restent a tester.

La recette complete est detaillee dans `VALIDATION_WINDOWS.md`. Pour terminer cette validation, il faut des VM jetables Windows 10/11 avec instantanes et un appareil mobile de test accessible.

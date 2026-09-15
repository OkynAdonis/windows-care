# Validation avant version stable

Version candidate : 1.0.1-rc.9. Les tests automatises utilisent des commandes simulees pour les modifications Windows ; ils ne remplacent pas cette recette. Les essais reels deja effectues sont consignes dans les fichiers `RESULTATS_RC*.md`.

Executer les actions de modification sur des machines virtuelles Windows 10 et 11 avec instantane initial, dans une session francaise puis anglaise lorsque possible. Les diagnostics et le rapport planifie ont ete verifies sur le poste Windows 11 ; les actions de modification et leur restauration restent a verifier en VM.

| Parcours | Resultat attendu |
|---|---|
| Extraire le ZIP dans un chemin avec espaces et lancer le BAT | Elevation, menu lisible ; choix 0 ferme l outil |
| Refuser l elevation | Sortie compréhensible, sans boucle de relancement |
| Activer la simulation, parcourir les actions | Aucun reglage Windows ni sauvegarde modifie ; journaux et rapports locaux autorises |
| Etat, score, disques, demarrage et rapport HTML | Resultats consultables ; erreurs explicites si une source est indisponible |
| Appliquer deux profils puis choix 22 | Plan demande actif ; retour au plan precedant le premier changement |
| Appliquer Search avec valeurs initialement absentes et presentes | Sauvegarde distincte ; restauration des anciennes valeurs et suppression des nouvelles |
| Appliquer confidentialite puis restaurer | Registre, modes et etats des services, et activation des taches identiques a l etat initial |
| DNS automatique puis DNS personnalises, restauration | Retour au mode automatique ou aux adresses initiales, IPv6 preserve |
| Interface originale absente lors de restauration | Refus explicite ; aucune autre interface modifiee |
| Sauvegarde impossible | Modification annulee, erreur journalisee |
| Windows Update, deux executions successives | Caches distincts conserves ; services auparavant actifs relances, y compris apres echec |
| Nettoyage avec fichiers verrouilles | Prefetch conserve ; resultat partiel signale ; limites de recuperation visibles avant confirmation |
| DISM/SFC et reinitialisation reseau | Codes retour journalises ; besoin de redemarrage signale ; SFC non lance apres echec DISM |
| Rapport hebdomadaire : declenchement manuel depuis le Planificateur | Rapport produit sans menu dans data, code retour 0 |
| Supprimer la tache avec -RemoveMaintenanceTask | Tache absente du Planificateur |
| Centre des applications sans WinGet | Message explicite indiquant App Installer ; retour propre au sous-menu |
| Centre des applications avec WinGet | Version et sources visibles ; mises a jour disponibles lisibles |
| Package WinGet installe pour l utilisateur | Reparation possible avec -StandardUser ; message explicite si elle est tentee en administrateur |
| Mise a jour d une application en simulation | Commande non executee et aucune application modifiee |
| Mise a jour d un identifiant exact | Seul le package choisi est traite ; resultat et code de sortie journalises |
| Reparation d un package compatible puis incompatible | Succes pour le premier ; limite WinGet clairement affichee pour le second |
| Export des applications | Fichier JSON horodate cree dans data et lisible par WinGet |
| Diagnostic systeme avance | Ressources coherentes, processus visibles, sources indisponibles expliquees |
| Evenements et stabilite | Absence de donnees geree ; rapport JSON produit meme si une source echoue |
| Defender en simulation | Aucune mise a jour de signatures et aucune analyse lancee |
| Defender rapide et complet | Progression Windows visible ; resultat ou erreur journalise sans faux succes |
| Defender hors ligne | Avertissement de redemarrage ; refus sans effet ; acceptation redemarre vers l analyse |
| Antivirus tiers ou Defender indisponible | Message clair ; aucune commande Defender forcee |
| Diagnostic progressif complet | Quatre etapes dans l ordre ; aucune reparation tant que le choix distinct n est pas confirme |
| Reseau avance hors ligne, VPN et proxy | Chaque couche echoue independamment ; aucune reinitialisation automatique |
| Installation Sysinternals | Un seul identifiant Microsoft exact transmis a WinGet apres confirmation |
| Lancement Sysinternals absent ou present | Absence expliquee ; lancement du seul outil choisi apres confirmation |
| Premiers secours sur quatre symptomes | Diagnostics adaptes ; aucune correction automatique ; conseil final lisible |
| Site sur mobile et sans JavaScript | Guide accessible, textes visibles, 36 actions, metadonnees conformes au ZIP |

Conserver les journaux et consigner pour chaque essai : edition/build de Windows, langue, compte utilise, resultat et anomalie. Ne publier une version stable qu apres resolution des echecs.

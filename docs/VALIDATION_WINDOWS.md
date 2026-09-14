# Validation avant version stable

Version candidate : 1.0.1-rc.2. Les tests automatises utilisent des commandes simulees pour les modifications Windows ; ils ne remplacent pas cette recette. Les essais reels deja effectues sont consignes dans `RESULTATS_RC2.md`.

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
| Site sur mobile et sans JavaScript | Guide accessible, textes visibles, 23 actions, metadonnees conformes au ZIP |

Conserver les journaux et consigner pour chaque essai : edition/build de Windows, langue, compte utilise, resultat et anomalie. Ne publier une version stable qu apres resolution des echecs.

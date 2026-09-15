# Windows Care - reste a faire avant la version officielle

Derniere mise a jour : 15 septembre 2026.

## Etat au moment de la pause

- Candidate locale en cours : `1.0.1-rc.9` ; la publication reste a effectuer.
- Site : https://okynadonis.github.io/windows-care/
- Dernier commit fonctionnel : `fcb34d2`.
- SHA-256 du ZIP public : `42FBCD13F63400188D1D065F26BAECB4E489CEEBE74A36B625BB8BB32B900080`.
- Menu : 36 actions avec explication avant execution, confirmation des mutations et indicateurs de progression.
- Validation automatisee : 47 tests moteur, 5 scenarios BAT et 54 assertions navigateur.
- Validation reelle acquise sur Windows 11 en session standard : score de sante, rapport planifie, reseau, Windows Update, pilotes, batterie et dossier de support.
- La version reste une preversion tant que la recette des mutations en VM n est pas terminee.

## Priorite 1 - recette Windows en VM

Preparer une VM Windows 10 et une VM Windows 11 avec un instantane propre avant les essais.

- [ ] Lancer le ZIP depuis un chemin simple puis depuis un chemin avec espaces et caracteres speciaux.
- [ ] Tester le lancement administrateur, le refus UAC et une session standard.
- [ ] Tester le mode simulation sur les 36 choix et confirmer qu aucune mutation ni sauvegarde systeme n est effectuee.
- [ ] Tester le centre des applications avec et sans WinGet, puis mettre a jour et reparer des packages compatibles et incompatibles.
- [ ] Comparer les ressources du diagnostic avance avec le Gestionnaire des taches et verifier les evenements sur Windows 10/11.
- [ ] Tester les analyses Defender rapide, complete et hors ligne, y compris avec un antivirus tiers.
- [ ] Tester les quatre etapes du diagnostic progressif sur un Windows sain puis volontairement endommage en VM.
- [ ] Tester le reseau avance hors ligne, derriere un proxy, avec VPN et interfaces virtuelles.
- [ ] Installer et lancer chaque outil Sysinternals propose, puis tester son absence et une installation refusee.
- [ ] Faire suivre les quatre parcours de premiers secours par un utilisateur qui ne connait pas PowerShell.
- [ ] Tester les profils Equilibre et Gaming, puis restaurer le plan avec le choix 22.
- [ ] Appliquer et restaurer les reglages de confidentialite et Windows Search.
- [ ] Configurer Google DNS et Cloudflare, puis restaurer le DNS automatique et un DNS personnalise initial.
- [ ] Verifier le refus propre de la restauration lorsque l interface reseau originale est absente.
- [ ] Executer deux reparations Windows Update et verifier les caches conserves ainsi que le redemarrage des services.
- [ ] Tester le nettoyage avec fichiers ordinaires, verrouilles et liens de reanalyse.
- [ ] Executer DISM puis SFC et verifier les codes de sortie, le loader et le besoin eventuel de redemarrage.
- [ ] Tester la reinitialisation reseau puis redemarrer la VM et verifier la connectivite.
- [ ] Creer un point de restauration avec la Protection du systeme activee, desactivee et indisponible.
- [ ] Revenir a l instantane initial apres chaque groupe d actions sensibles.

Pour chaque essai, conserver la version et la langue de Windows, le type de compte, le resultat, le journal de session et une capture en cas d anomalie. Utiliser la matrice `VALIDATION_WINDOWS.md`.

## Priorite 2 - configurations et materiels varies

- [ ] Tester Windows en francais et en anglais.
- [ ] Tester un portable avec batterie et un ordinateur fixe sans batterie.
- [ ] Tester sans Internet, avec Wi-Fi, Ethernet, VPN et plusieurs interfaces virtuelles.
- [ ] Tester avec un antivirus tiers et avec des politiques d entreprise si une machine adaptee est disponible.
- [ ] Tester un peripherique possedant un vrai code erreur dans le Gestionnaire de peripheriques.
- [ ] Verifier le dossier de support lorsque certaines sources CIM sont bloquees.
- [ ] Confirmer que les informations indisponibles restent expliquees sans interrompre les autres diagnostics.

## Priorite 3 - recette interface et accessibilite

- [ ] Tester le site sur un telephone Android reel.
- [ ] Tester le site sur un iPhone reel.
- [ ] Lire le QR code sur Android et iPhone.
- [ ] Parcourir toutes les commandes au clavier dans Chrome, Edge et Firefox.
- [ ] Tester le zoom navigateur a 200 % et 400 %.
- [ ] Tester le mode de mouvement reduit et verifier que les loaders restent comprehensibles.
- [ ] Faire un parcours avec Narrateur Windows ou NVDA.
- [ ] Remplacer la capture ancienne du menu par une capture propre montrant les 36 actions.

## Priorite 4 - retours des premiers utilisateurs

- [ ] Faire essayer la candidate a quelques collegues en commencant par `-DryRun`.
- [ ] Demander le symptome initial, l action choisie et le resultat observe.
- [ ] Recuperer le dossier de support uniquement apres relecture par son proprietaire.
- [ ] Creer un ticket GitHub par anomalie reproductible.
- [ ] Corriger les anomalies importantes et ajouter un test de regression pour chacune.
- [ ] Refaire toute la recette apres la derniere correction.

## Passage en version stable 1.0.1

Effectuer ces operations uniquement lorsque les listes precedentes sont terminees et qu aucun probleme bloquant ne reste ouvert.

- [ ] Mettre a jour les resultats de validation avec les preuves Windows 10 et Windows 11.
- [ ] Lancer le build complet et les tests navigateur une derniere fois.
- [ ] Verifier le contenu du ZIP, sa taille, son manifeste et son SHA-256.
- [ ] Retirer la mention `Version de test publique` du site.
- [ ] Remplacer la version candidate par `1.0.1` dans le build, la documentation et le site.
- [ ] Creer le commit de publication stable.
- [ ] Creer le tag Git `v1.0.1` et la release GitHub avec le ZIP et son SHA-256.
- [ ] Verifier le ZIP telecharge depuis le site public apres deploiement.

## Points a ne pas oublier

- `site/assets/windowscarelogobck.png` est le logo transparent officiel actuellement utilise.
- `site/assets/windowscarelogo.png` est une variante locale non suivie et ne doit pas etre publiee sans nouvelle decision explicite.
- Ne pas ajouter de suppression massive d Edge, Microsoft Store, Defender, Windows Update ou des pilotes sans sauvegarde, restauration, tests VM et besoin utilisateur confirme.
- Une premiere version stable termine le cycle `1.0.1`, mais la maintenance devra continuer lorsque Windows change ou lorsqu un utilisateur signale une anomalie.

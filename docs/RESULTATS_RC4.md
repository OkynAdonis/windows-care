# Validation de la candidate 1.0.1-rc.4

Date : 15 septembre 2026. Statut : preversion publique, validation stable incomplete.

## Orientation issue de la comparaison

Les fonctions de WinUtil et WinScript ainsi que leurs retours GitHub et Reddit ont ete examines avant cette iteration. Les suppressions massives de composants, la desactivation de Windows Update et les modifications d ISO ne sont pas ajoutees : elles augmenteraient le risque de casser Microsoft Store, Winget, Explorer, les jeux ou les futures mises a jour.

Windows Care renforce plutot le diagnostic et l assistance avec six actions :

- diagnostic reseau separe entre interface, DNS et connexion HTTPS ;
- etat des services Windows Update, derniers correctifs et redemarrage en attente ;
- liste des peripheriques dont le pilote possede un code erreur Windows ;
- rapport batterie produit par `powercfg` ;
- creation explicite d un point de restauration Windows ;
- dossier de support local avec avertissement avant partage.

## Verifications automatisees

- 36 tests du moteur PowerShell, sans modification de la configuration Windows ;
- 4 scenarios du lanceur BAT ;
- 51 assertions navigateur, incluant les 29 cartes du guide ;
- contenu du ZIP, manifeste et SHA-256 verifies ;
- construction reproductible avec fins de ligne et metadonnees ZIP normalisees.

## Essai reel Windows 11 en session standard

- diagnostic reseau reussi avec VPN, Wi-Fi et interfaces virtuelles ; resolution DNS et connexion TCP 443 confirmees ;
- trois services Windows Update lus et redemarrage en attente detecte ;
- aucun peripherique avec code erreur trouve ;
- dossier de support produit avec JSON valide, cinq mesures de sante, inventaire de demarrage, journal et avertissement de confidentialite.
- rapport batterie officiel produit avec succes par Windows.

## Blocages avant version stable

- Executer toutes les actions de modification et restauration dans une VM Windows 10 et une VM Windows 11 avec instantanes.
- Verifier le point de restauration lorsque la Protection du systeme est activee, desactivee et indisponible.
- Tester les nouveaux diagnostics sur plusieurs cartes reseau, un PC sans Internet, un portable avec batterie et un peripherique en erreur.
- Faire la recette tactile, QR code et lecteur d ecran sur des appareils reels.

Les validations anterieures restent disponibles dans `RESULTATS_RC2.md` et `RESULTATS_RC3.md`.

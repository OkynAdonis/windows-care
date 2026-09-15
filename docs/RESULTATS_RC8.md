# Validation de la candidate 1.0.1-rc.8

Date : 15 septembre 2026. Statut : candidate locale, validation Windows reelle incomplete.

## Diagnostic systeme avance

Le choix 31 ouvre un sous-menu en lecture seule pour afficher les ressources, les processus les plus lourds, les erreurs critiques des dernieres 48 heures et l historique de stabilite. Un export JSON tolere les sources indisponibles et regroupe aussi les pilotes en erreur et les raisons d un redemarrage en attente.

## Centre Microsoft Defender

Le choix 32 affiche l etat de la protection et l historique des menaces. Il propose la mise a jour des signatures, une analyse rapide, une analyse complete et une analyse hors ligne. Chaque operation active demande une confirmation et reste bloquee par le mode simulation. L analyse hors ligne annonce explicitement le redemarrage.

## Sous-menus

Les centres Applications, Diagnostic systeme et Defender utilisent des sous-menus avec un choix 0 pour revenir au menu principal. Cette structure limite la longueur du menu principal et separe les diagnostics des operations actives.

## Verification restante

Tester les valeurs sur Windows 10 et 11, les journaux d evenements restreints, Defender desactive ou remplace par un antivirus tiers, ainsi que les trois types d analyse. Les tests automatises ne doivent lancer aucune analyse reelle.

## Verifications automatisees

- 44 tests du moteur ;
- 4 scenarios du lanceur BAT ;
- 52 assertions navigateur ;
- aucune configuration Windows ni analyse Defender declenchee par ces tests.

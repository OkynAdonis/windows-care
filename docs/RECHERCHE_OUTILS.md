# Recherche comparative des outils Windows

Date de consultation : 14 et 15 septembre 2026.

## Sources consultees

- WinUtil : https://github.com/ChrisTitusTech/winutil
- Problemes ouverts WinUtil : https://github.com/ChrisTitusTech/winutil/issues
- Problemes connus WinUtil : https://winutil.christitus.com/knownissues/
- WinScript : https://github.com/flick9000/winscript
- Discussion Reddit sur l usage de WinUtil et la restauration : https://www.reddit.com/r/ROGAllyX/comments/1to0314/winutil_for_debloat_windows/
- Discussion Reddit sur les risques du debloat Windows 11 : https://www.reddit.com/r/pcgamingtechsupport/comments/1p64xqe/debloating_win11_without_breaking_it/

## Conclusions appliquees a Windows Care

WinUtil couvre beaucoup plus de fonctions et distingue les reparations ordinaires des operations agressives. WinScript propose surtout de composer des scripts de suppression, confidentialite, performance et installation d applications.

Les retours utilisateurs montrent que les suppressions de composants peuvent produire des conflits difficiles a reproduire, surtout sur une machine deja utilisee. Un point de restauration peut aussi etre indisponible ou ne pas avoir ete cree malgre l annonce d un outil. Windows Care ne doit donc pas presenter une suppression massive comme une reparation universelle.

La rc.4 ajoute des diagnostics par couches, un export de support, un rapport batterie et une creation explicite de point de restauration. Elle conserve les protections suivantes : execution locale, aucune commande telechargee puis executee, confirmation des mutations, sauvegardes par categorie, refus des mutations sans elevation et mode simulation.

Aucun code des projets examines n a ete copie. Leur organisation, leurs fonctions visibles et les problemes publics ont servi a definir les besoins et les cas d echec.

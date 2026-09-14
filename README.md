# Windows Care by TECH EXCHANGE

Windows Care est un outil local de diagnostic, maintenance et optimisation pour Windows 10 et Windows 11.

TECH EXCHANGE est la plateforme creee et developpee par son fondateur developpeur.

## Demarrage

1. Telecharger ou cloner le projet.
2. Lancer `app\SCRIPT_TOOL.bat`.
3. Accepter l elevation administrateur lorsque Windows la demande.
4. Choisir une action dans le menu vertical.

Le menu propose 23 actions. Le mode `-DryRun` bloque les modifications systeme et les sauvegardes ; les diagnostics, journaux et rapports locaux restent disponibles.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\app\SCRIPT_TOOL.ps1 -DryRun
powershell -NoProfile -ExecutionPolicy Bypass -File .\app\SCRIPT_TOOL.ps1 -ReportOnly
```

Les donnees sont stockees dans `app\data` dans le depot, ou `data` a cote du moteur apres extraction du ZIP. Conserver `State.ps1` avec `SCRIPT_TOOL.ps1`.

## Sauvegardes et limites

- Chaque modification de confidentialite, Search, DNS ou alimentation cree une sauvegarde distincte. Un echec de sauvegarde bloque cette modification.
- Le choix 20 restaure une categorie sur le meme ordinateur et avec le meme compte Windows, apres sauvegarde de son etat courant. Les DNS retrouvent leurs adresses ou leur mode automatique, sur l interface identifiee par son GUID.
- Les valeurs du registre creees par l outil sont supprimees lorsqu elles etaient absentes. Les services et taches de confidentialite retrouvent leur etat sauvegarde.
- Les anciennes sauvegardes partielles restent conservees, mais leur restauration doit etre manuelle. Les nouvelles sauvegardes utilisent `state.xml` et un manifeste de schema 2.
- Les fichiers temporaires et la corbeille ne sont pas sauvegardes. Le Prefetch est conserve. DISM/SFC et la reinitialisation reseau ne disposent pas de retour arriere dans Windows Care. Les anciens caches Windows Update sont conserves sous un nom unique dans leur dossier d origine, sans restauration automatique.
- Le score est un indicateur simplifie, pas une certification de securite ni un test complet de Windows ou de la connexion Internet.

## Maintenance automatique

Le choix 19 planifie `-ReportOnly` chaque dimanche a 10 h pour le compte connecte, avec rattrapage lorsque possible et une limite de 15 minutes. Replanifier apres deplacement du dossier. Pour supprimer la tache, depuis une console administrateur :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\app\SCRIPT_TOOL.ps1 -RemoveMaintenanceTask
```

Le choix 22 restaure manuellement le plan precedent ; il n y a pas de restauration automatique a la fermeture. Le profil Bureautique utilise le plan Equilibre.

## Validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Tool.ps1
```

Les tests chargent les fonctions sans demarrer le menu et simulent les modifications systeme. La version `1.0.1-rc.1` doit encore etre validee sur des machines virtuelles Windows 10 et 11 avant diffusion comme version stable. Voir `docs/VALIDATION_WINDOWS.md`.

## Release

Le script `build-release.ps1` execute les tests, verifie les fichiers requis, construit `release\SCRIPT_TOOL.zip`, calcule son SHA-256, copie l archive dans `site` et genere `site/version.json` ainsi que les informations de telechargement des pages HTML.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build-release.ps1 -Version 1.0.1-rc.1
```

## Site

Le dossier `site` contient la page de presentation, le guide des 23 actions et l archive telechargeable. Le workflow GitHub Pages teste et reconstruit la release sous Windows avant de publier le site a chaque push sur `main`.

## Organisation

- `app` : lanceur BAT et moteur PowerShell Windows Care ;
- `site` : site public et archive telechargeable ;
- `docs` : audits et documentation historique ;
- `legacy` : anciens scripts conserves comme reference ;
- `branding` : sources du logo TECH EXCHANGE ;
- `release` : archives generees par le build ;
- `build-release.ps1` : processus reproductible de publication.

## GitHub Pages

1. Creer un depot public sur le compte `OkynAdonis`.
2. Pousser la branche `main`.
3. Dans **Settings > Pages**, choisir **GitHub Actions** comme source.
4. Le workflow `.github/workflows/pages.yml` publiera le site.

Contact : `okengueadonis@gmail.com`  
TECH EXCHANGE : `techexchange50@gmail.com`  
Telephone : `+241 77 17 14 32`

# Windows Care by TECH EXCHANGE

Windows Care est un outil local de diagnostic, maintenance et optimisation pour Windows 10 et Windows 11.

TECH EXCHANGE est la plateforme creee et developpee par son fondateur developpeur.

## Demarrage

1. Telecharger ou cloner le projet.
2. Lancer `SCRIPT_TOOL.bat`.
3. Accepter l elevation administrateur lorsque Windows la demande.
4. Choisir une action dans le menu vertical.

Le mode `-DryRun` permet de parcourir les actions sans modifier Windows.

## Release

Le script `build-release.ps1` valide la syntaxe, verifie les fichiers requis, construit `SCRIPT_TOOL.zip`, calcule son SHA-256, copie l archive dans `site` et genere `site/version.json`.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build-release.ps1 -Version 1.0.0
```

## Site

Le dossier `site` contient la page de presentation, le guide des 21 actions et l archive telechargeable. Le workflow GitHub Pages publie automatiquement le contenu de `site` a chaque push sur `main`.

## GitHub Pages

1. Creer un depot public sur le compte `OkynAdonis`.
2. Pousser la branche `main`.
3. Dans **Settings > Pages**, choisir **GitHub Actions** comme source.
4. Le workflow `.github/workflows/pages.yml` publiera le site.

Contact : `okengueadonis@gmail.com`  
TECH EXCHANGE : `techexchange50@gmail.com`  
Telephone : `+241 77 17 14 32`

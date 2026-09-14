# Tests locaux

Depuis la racine du projet, sous Windows :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Test-Tool.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Test-Launcher.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Test-Site.ps1
```

- `Test-Tool.ps1` : 29 tests du moteur ; modifications Windows simulées.
- `Test-Launcher.ps1` : 4 scénarios réels du BAT avec moteur factice, sans élévation, dans un chemin contenant espaces, apostrophe et esperluette.
- `Test-Site.ps1` : 35 assertions dans Chrome ou Edge sans interface, avec profil temporaire isolé. Utiliser `-BrowserPath` pour indiquer un autre emplacement du navigateur.

Les tests web chargent le HTML, le CSS et le JavaScript actuels dans des pages isolées, embarquent les images locales et désactivent le téléchargement des polices Google. Ils couvrent la recherche, les téléchargements répétés, les liens natifs, la restauration de page, l'absence de JavaScript ou d'IntersectionObserver, le changement de préférence de mouvement et les débordements à 320, 360, 768 et 1280 pixels.

Ils ne remplacent pas une inspection visuelle avec les polices téléchargées, un essai sur téléphone réel ou une validation avec lecteur d'écran. Les workflows de publication et de pull request exécutent les tests du moteur, du lanceur et du navigateur.

## Essai réel du rapport planifié (opt-in)

Depuis une console administrateur :

```powershell
powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tests/Test-ScheduledReport.ps1 -EvidenceDirectory C:\chemin\vers\preuves
```

Ce test crée une tâche temporaire de nom unique, lance le diagnostic réel sans modification des réglages Windows, vérifie son rapport et son code de retour, puis supprime la tâche. Les preuves et rapports restent dans le dossier indiqué. Ce test n'est pas lancé automatiquement par le build.

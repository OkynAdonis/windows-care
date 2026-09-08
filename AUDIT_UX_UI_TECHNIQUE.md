# Audit UX/UI et technique
## TECH EXCHANGE / Windows Care

**Date :** 8 septembre 2026  
**Périmètre :** site public, guide des 21 actions, parcours de téléchargement et outil Windows PowerShell/BAT.  
**Positionnement retenu :** TECH EXCHANGE est la plateforme créée par son fondateur développeur. Windows Care est le premier produit présenté.

---

## 1. Synthèse exécutive

Le projet possède déjà une identité forte : palette reconnaissable, typographie cohérente, logo officiel, page d'accueil, page de guide et téléchargement local. Le site donne une impression de produit réel plutôt que de simple page technique.

Les priorités pour atteindre un niveau professionnel sont désormais :

1. rendre la promesse de Windows Care immédiatement explicite ;
2. relier les informations affichées sur le site aux données réellement produites par l'outil ;
3. clarifier la hiérarchie TECH EXCHANGE / Windows Care sur toutes les pages ;
4. renforcer l'accessibilité, les états clavier et la lisibilité mobile ;
5. fiabiliser le packaging et le processus de publication ;
6. sécuriser les actions système et leurs mécanismes de restauration.

**Avis global :** bonne base de marque et de présentation, mais le projet est encore au stade « produit bien présenté » plutôt que « produit distribué et industrialisé ». La prochaine étape ne doit pas être uniquement esthétique : elle doit connecter l'expérience marketing, la documentation et le comportement réel de l'application.

---

## 2. Audit UX/UI

### 2.1 Points forts

- Identité visuelle distincte : vert lime, turquoise, encre sombre et accent sable.
- Hiérarchie typographique claire avec Manrope et DM Mono.
- Hero visuel immédiatement identifiable.
- Appel au téléchargement présent à plusieurs endroits.
- Guide séparé pour les 21 actions : bonne décision pour éviter de surcharger l'accueil.
- Captures d'écran réelles du produit et du site.
- Footer complet avec navigation, contact et signature de la plateforme.
- Motion design léger plutôt que décoratif : entrée du dashboard, révélations au défilement, transitions au survol.
- Respect prévu de `prefers-reduced-motion`.

### 2.2 Points à améliorer

#### A. Promesse du produit

Le hero parle encore beaucoup de la plateforme et des solutions numériques alors que la page sert principalement à télécharger Windows Care. La première lecture devrait répondre en quelques secondes à :

- quel est le produit ?
- pour quel problème ?
- pour quelle version de Windows ?
- que se passe-t-il après le clic ?

**Suggestion :** afficher Windows Care comme titre principal, puis présenter TECH EXCHANGE comme créateur dans le sous-texte et le footer.

#### B. Conversion téléchargement

Le téléchargement est visible, mais il manque une information rassurante près du bouton : taille de l'archive, date de version, compatibilité, droits administrateur et mode simulation.

**Suggestion :** ajouter sous le bouton :

> Windows 10/11 · Archive ZIP · Exécution locale · Droits administrateur requis pour les actions système.

Ajouter aussi une section courte « Après téléchargement » en trois étapes : décompresser, lancer le BAT, choisir une action.

#### C. Démonstration

Les captures montrent l'interface, mais elles ne montrent pas encore un résultat concret : score de santé, rapport HTML ou restauration.

**Suggestion :** ajouter une capture ou une animation courte du parcours :

1. menu ;
2. choix du score ;
3. résultat ;
4. rapport généré.

#### D. Navigation

La navigation est minimale, ce qui est élégant, mais le guide n'est pas toujours assez visible sur mobile où le lien est masqué.

**Suggestion :** remplacer le lien masqué par un menu compact ou un bouton icône accessible, ou conserver « Guide » visible en permanence.

#### E. Cohérence des sections

L'accueil possède plusieurs sections numérotées et le guide recommence à `01`. Cela peut être compris comme deux systèmes de numérotation différents, mais ce n'est pas explicite.

**Suggestion :** utiliser des labels sémantiques distincts : « Ce que nous construisons », « Le produit », « À propos », puis garder la numérotation uniquement pour les actions du guide.

#### F. Interactions

Les cartes changent de couleur au survol, ce qui donne une personnalité au site. Il faut toutefois garantir le même feedback au clavier et sur les appareils tactiles.

**Suggestion :** ajouter `:focus-visible`, un état actif utilisable au clavier et une alternative non dépendante du hover sur mobile.

#### G. Accessibilité

À renforcer :

- contraste à vérifier pour tous les textes secondaires ;
- focus clavier visible sur les liens et boutons ;
- texte alternatif plus descriptif pour chaque capture ;
- structure des titres à vérifier avec un lecteur d'écran ;
- indication claire lorsque le téléchargement commence ;
- éviter de faire dépendre une information uniquement de la couleur.

#### H. Motion design

Le niveau actuel est volontairement discret, ce qui est positif. Il manque cependant une relation entre le mouvement et le produit.

**Suggestions acceptables :**

- animation de progression du score de santé ;
- révélation séquencée des 21 actions dans le guide ;
- micro-animation du bouton de téléchargement après clic ;
- transition de navigation entre accueil et guide ;
- effet de ligne ou curseur dans l'aperçu console ;
- aucun mouvement permanent agressif.

Le principe doit rester : le mouvement explique, confirme ou guide. Il ne doit pas distraire.

---

## 3. Audit technique senior

### 3.1 Points forts

- Séparation claire entre lanceur BAT et logique PowerShell.
- Journalisation par session.
- Sauvegardes avant plusieurs opérations sensibles.
- Mode simulation.
- Confirmation avant les actions destructives ou structurantes.
- Guide public correspondant au menu de l'application.
- Site statique facile à publier.
- Ressources locales disponibles pour fonctionner sans backend.

### 3.2 Risques et corrections prioritaires

#### A. Chiffres illustratifs sur le site

Le dashboard affiche `86/100`, `94`, `100` et `72` comme si ces valeurs étaient réelles. Elles sont actuellement statiques et ne viennent pas de l'ordinateur du visiteur.

**Risque :** présentation potentiellement trompeuse.

**Correction recommandée :** remplacer « LIVE » par « Aperçu » et préciser que les chiffres sont une démonstration, ou générer une capture explicitement marquée « Exemple ».

#### B. Décalage entre documentation et application

Le guide décrit 21 actions, mais les noms et les comportements devront rester synchronisés manuellement.

**Correction recommandée :** créer une définition centrale des actions dans PowerShell ou un fichier JSON, puis générer le menu, le guide et éventuellement les métadonnées depuis cette source.

#### C. Gestion des erreurs système

Plusieurs commandes externes peuvent retourner un code d'erreur sans lever d'exception PowerShell. Dans ce cas, `Invoke-Action` peut afficher « terminé » alors que la commande a échoué.

**Correction recommandée :** créer un wrapper `Invoke-NativeCommand` qui contrôle `$LASTEXITCODE`, capture stdout/stderr et journalise le résultat réel.

#### D. Sauvegarde incomplète

La sauvegarde couvre principalement quelques clés registre, DNS, plan d'alimentation et services. La restauration ne remet pas encore tous les éléments sauvegardés, notamment les paramètres DNS et les états de services.

**Correction recommandée :** définir un contrat de sauvegarde versionné avec manifest JSON, statut de chaque élément et restauration indépendante par catégorie.

#### E. Restauration registre

Importer un fichier `.reg` peut restaurer des valeurs, mais ne garantit pas la suppression de valeurs ajoutées après la sauvegarde.

**Correction recommandée :** documenter cette limite et ajouter une sauvegarde complète avant restauration. Pour les paramètres gérés par PowerShell, préférer une restauration explicite des valeurs connues.

#### F. Profils de performance

Le profil Bureautique active actuellement le plan Haute performance, ce qui peut être excessif sur un portable. Le profil Gaming ne restaure pas automatiquement l'état précédent.

**Correction recommandée :** sauvegarder le plan actif, afficher le coût énergétique et proposer une restauration temporaire après session.

#### G. Tâche planifiée

La tâche hebdomadaire utilise un chemin de script local et dépend de l'emplacement du dossier. Un déplacement de l'outil peut casser la tâche.

**Correction recommandée :** enregistrer le chemin absolu dans un manifest, vérifier son existence avant exécution et ajouter une option de suppression de la tâche.

#### H. Packaging

L'archive ZIP doit toujours être régénérée après modification du moteur. Le site peut donc présenter une version différente du dossier principal.

**Correction recommandée :** script `build-release.ps1` qui :

- valide la syntaxe ;
- vérifie les fichiers requis ;
- crée l'archive ;
- calcule un SHA-256 ;
- copie l'archive dans `site` ;
- génère un fichier de version.

#### I. Signature et confiance

Pour une distribution publique, Windows peut afficher des avertissements concernant les scripts téléchargés.

**Correction recommandée :** publier un hash SHA-256, expliquer les droits administrateur et, à terme, signer les scripts ou fournir un installateur signé.

#### J. Sécurité du site

Le site statique ne doit pas promettre une sécurité absolue. Les actions de télémétrie, registre, DNS et réseau peuvent modifier durablement Windows.

**Correction recommandée :** afficher clairement les actions sensibles, la sauvegarde, la restauration et les limites de compatibilité.

#### K. Qualité du code web

Le CSS contient actuellement plusieurs media queries `max-width:760px` qui se recouvrent. Cela fonctionne, mais augmente le risque de régression.

**Correction recommandée :** fusionner les règles responsive par breakpoint et utiliser des composants ou classes plus explicites.

#### L. Encodage et publication

Les fichiers HTML contiennent des caractères accentués tandis que certains fichiers historiques sont en ASCII sans accents. Il faut conserver UTF-8 pour le site et éviter les incohérences de terminal.

**Correction recommandée :** déclarer UTF-8 partout où des accents sont utilisés et tester le site via serveur HTTP, pas seulement avec `start index.html`.

---

## 4. Backlog de propositions

### Priorité P0 : avant diffusion publique

| ID | Proposition | Bénéfice | Effort |
|---|---|---|---|
| P0-01 | Marquer les chiffres du dashboard comme « Exemple » ou les rendre dynamiques | Évite une promesse trompeuse | Faible |
| P0-02 | Ajouter version, date, taille et SHA-256 du téléchargement | Renforce la confiance | Faible |
| P0-03 | Contrôler les codes retour des commandes externes | Évite les faux succès | Moyen |
| P0-04 | Fusionner et nettoyer les media queries CSS | Réduit les régressions | Faible |
| P0-05 | Ajouter focus clavier et états `:focus-visible` | Accessibilité et qualité | Faible |

### Priorité P1 : expérience produit

| ID | Proposition | Bénéfice | Effort |
|---|---|---|---|
| P1-01 | Ajouter un parcours « Après téléchargement » | Réduit les abandons | Faible |
| P1-02 | Ajouter une vraie démonstration score -> rapport | Rend le produit tangible | Moyen |
| P1-03 | Générer guide et menu depuis une source d'actions unique | Évite les divergences | Moyen |
| P1-04 | Ajouter recherche ou filtres au guide des 21 actions | Accélère la consultation | Faible |
| P1-05 | Ajouter un bouton « Voir le guide » visible sur mobile | Meilleure navigation | Faible |
| P1-06 | Ajouter profils avant/après avec restauration | Meilleure compréhension des changements | Moyen |

### Priorité P2 : industrialisation

| ID | Proposition | Bénéfice | Effort |
|---|---|---|---|
| P2-01 | Créer `build-release.ps1` | Publication reproductible | Moyen |
| P2-02 | Ajouter manifest de sauvegarde versionné | Restauration fiable | Élevé |
| P2-03 | Ajouter tests PowerShell sur les fonctions non destructives | Réduit les régressions | Moyen |
| P2-04 | Publier une page changelog/version | Transparence produit | Faible |
| P2-05 | Signer les scripts ou produire un installateur signé | Confiance Windows | Élevé |
| P2-06 | Ajouter suppression de la tâche de maintenance | Gouvernance complète | Faible |

---

## 5. Décisions à valider avant implémentation

Répondre avec les IDs à accepter, par exemple : `P0-01, P0-02, P1-01, P1-04`.

1. Le dashboard doit-il afficher un exemple explicitement marqué, ou doit-il être supprimé ?
2. Windows Care doit-il rester un outil portable ZIP ou évoluer vers un installateur ?
3. Les profils de performance doivent-ils être temporaires avec restauration automatique ?
4. Les réglages de confidentialité doivent-ils avoir un profil prudent et un profil renforcé ?
5. Le site doit-il rester une page statique ou évoluer vers plusieurs pages de présentation de produits ?
6. Souhaitez-vous afficher votre nom personnel, ou uniquement « Fondateur et développeur de TECH EXCHANGE » ?

---

## 6. Plan d'implémentation recommandé

### Phase 1 : confiance et fiabilité

- corriger les faux indicateurs du dashboard ;
- ajouter version/hash/taille ;
- fiabiliser les codes retour ;
- nettoyer le CSS responsive ;
- ajouter focus clavier ;
- régénérer et valider l'archive.

### Phase 2 : expérience Windows Care

- source centrale des 21 actions ;
- guide généré ou synchronisé ;
- assistant de réparation amélioré ;
- rapports avant/après ;
- profils avec restauration.

### Phase 3 : diffusion TECH EXCHANGE

- changelog ;
- page produits ;
- processus de release ;
- hash public ;
- signature ou installateur ;
- documentation utilisateur complète.

---

## 7. Conclusion constructive

Le projet est crédible visuellement et possède une vraie direction. Le principal risque n'est plus le manque d'idées, mais l'écart possible entre ce que le site promet et ce que l'outil garantit techniquement.

Mon avis de développeur senior : consolider la fiabilité, la traçabilité et la cohérence des données avant d'ajouter beaucoup de nouvelles fonctions. Un outil plus petit mais vérifiable, restaurable et correctement documenté inspirera davantage confiance qu'un outil très riche affichant des résultats approximatifs.

Après validation des propositions, les implémentations seront réalisées par lots courts, avec validation ciblée après chaque lot et mise à jour du présent document.

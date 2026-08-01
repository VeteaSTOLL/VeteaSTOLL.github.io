# VeteaSTOLL.github.io

Site perso avec des démos Three.js (shaders custom, iridescence de couche mince, fractale de Mandelbrot). Le projet utilise [Vite](https://vitejs.dev/) comme bundler et [npm](https://www.npmjs.com/) pour gérer les dépendances (`three`, `lil-gui`), au lieu de fichiers vendored à la main.

## Structure du projet

```
.
├── index.html              # page d'accueil (liens vers les démos)
├── shadercool.html          # page de la démo "shader cool"
├── mandelbrot.html          # page de la démo Mandelbrot
├── iridescence.html         # page de la démo iridescence
├── main.css                 # style partagé
├── src/
│   ├── shadercool/
│   │   ├── main.js          # logique Three.js + GUI de la démo
│   │   ├── vertex.glsl       # vertex shader
│   │   └── fragment.glsl     # fragment shader
│   ├── mandelbrot/
│   │   ├── main.js
│   │   ├── vertex.glsl
│   │   └── fragment.glsl
│   └── iridescence/
│       ├── main.js
│       ├── vertex.glsl
│       └── fragment.glsl
├── public/                  # fichiers statiques copiés tels quels dans le build
│   ├── models/               # .obj (tortue, fin)
│   └── textures/             # envMap.jpg
├── vite.config.js           # config Vite (app multi-pages)
└── .github/workflows/deploy.yml  # CI: build + déploiement sur GitHub Pages
```

Chaque page HTML ne contient plus que la structure + `<script type="module" src="/src/.../main.js">` : tout le JS (et les shaders GLSL) vit dans `src/`.

## Installation

Prérequis : [Node.js](https://nodejs.org/) (v18+ recommandé) et npm.

```bash
npm install
```

## Développement local

```bash
npm run dev
```

Lance un serveur de dev Vite avec rechargement à chaud. Par défaut sur http://localhost:5173, avec des liens directs vers `/index.html`, `/shadercool.html`, `/mandelbrot.html` et `/iridescence.html`.

### Démo iridescence

Simulation d'une couche mince semi-transparente posée sur une couche réflective (bulle de savon, film d'huile). Deux modèles spectraux sont disponibles depuis la GUI :

- **Belcour–Barla** (défaut) — l'intégrale spectrale est évaluée analytiquement dans l'espace de Fourier ([Belcour & Barla 2017](https://belcour.github.io/blog/research/2017/05/01/brdf-thin-film.html)). Coût constant, anti-aliasing spectral gratuit, mais suppose un milieu non dispersif : le curseur de Cauchy `C2` est donc masqué.
- **Référence spectrale** — intégration explicite sur *N* longueurs d'onde, avec les fonctions colorimétriques CIE 1931 approchées par [Wyman et al. 2013](http://jcgt.org/published/0002/02/01/). Bien plus coûteuse, mais gère la dispersion de Cauchy et sert à valider le mode analytique : à `C2 = 0` et 128 longueurs d'onde, les deux modes doivent donner la même image.

## Build de production

```bash
npm run build
```

Génère le site statique final dans `dist/` (HTML/JS/CSS minifiés et hashés, assets de `public/` copiés tels quels). Pour prévisualiser ce build localement :

```bash
npm run preview
```

## Déploiement (GitHub Pages)

Le dépôt contient un workflow GitHub Actions (`.github/workflows/deploy.yml`) qui, à chaque push sur `main` :

1. installe les dépendances (`npm ci`),
2. build le site (`npm run build`),
3. publie le contenu de `dist/` sur GitHub Pages.

**À faire une seule fois** pour activer ce mode sur ce dépôt (`VeteaSTOLL/VeteaSTOLL.github.io`) :

1. Aller dans **Settings → Pages** du dépôt GitHub.
2. Dans **Build and deployment → Source**, choisir **GitHub Actions** (au lieu de "Deploy from a branch").
3. Pousser sur `main` : le workflow se déclenche automatiquement et le site est publié sur `https://veteastoll.github.io/`.

Il n'y a plus besoin de commiter de fichiers de build : `dist/` et `node_modules/` sont ignorés par git (voir `.gitignore`).

## Ajouter une nouvelle démo

1. Créer `ma-demo.html` à la racine (copier la structure d'une page existante).
2. Créer `src/ma-demo/main.js` (+ `.glsl` si besoin de shaders).
3. Référencer le script dans le HTML : `<script type="module" src="/src/ma-demo/main.js"></script>`.
4. Ajouter l'entrée dans `vite.config.js` (`build.rollupOptions.input`).

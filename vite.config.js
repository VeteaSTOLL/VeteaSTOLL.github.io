import { defineConfig, normalizePath } from 'vite';
import { resolve } from 'path';
import { readdirSync } from 'fs';

// public/ est recopié tel quel : Vite n'en analyse pas le contenu, et le navigateur ne peut pas
// le lister (GitHub Pages ne sert aucun index de répertoire). On dresse donc l'inventaire des
// .obj côté Node, exposé comme module virtuel — déposer un fichier dans public/models suffit
// alors à le faire apparaître dans la liste des modèles.
const MODELS_DIR = normalizePath(resolve(__dirname, 'public/models'));
const MODELS_ID = 'virtual:models';
const MODELS_RESOLVED = '\0' + MODELS_ID;

function modelsManifest() {
	return {
		name: 'models-manifest',

		resolveId(id) {
			if (id === MODELS_ID) return MODELS_RESOLVED;
		},

		load(id) {
			if (id !== MODELS_RESOLVED) return;

			let fichiers = [];
			try {
				fichiers = readdirSync(MODELS_DIR).filter(f => f.toLowerCase().endsWith('.obj')).sort();
			} catch {
				this.warn(`${MODELS_DIR} illisible : aucun modèle ne sera proposé`);
			}

			return `export default ${JSON.stringify(fichiers)};`;
		},

		configureServer(server) {
			// Le dossier n'est importé par personne : sans ça le watcher ne le surveillerait pas.
			server.watcher.add(MODELS_DIR);

			// Déposer ou retirer un .obj pendant que le serveur tourne rafraîchit la liste
			const relire = (file) => {
				if (!normalizePath(file).startsWith(MODELS_DIR)) return;
				const mod = server.moduleGraph.getModuleById(MODELS_RESOLVED);
				if (mod) server.moduleGraph.invalidateModule(mod);
				server.ws.send({ type: 'full-reload' });
			};

			server.watcher.on('add', relire);
			server.watcher.on('unlink', relire);
		},
	};
}

export default defineConfig({
	base: '/',
	plugins: [modelsManifest()],
	build: {
		outDir: 'dist',
		rollupOptions: {
			input: {
				main: resolve(__dirname, 'index.html'),
				shadercool: resolve(__dirname, 'shadercool.html'),
				mandelbrot: resolve(__dirname, 'mandelbrot.html'),
				iridescence: resolve(__dirname, 'iridescence.html'),
			},
		},
	},
});

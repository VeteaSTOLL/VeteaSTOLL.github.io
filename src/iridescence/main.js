import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { OBJLoader } from 'three/addons/loaders/OBJLoader.js';
import { mergeGeometries, toCreasedNormals } from 'three/addons/utils/BufferGeometryUtils.js';
import { GUI } from 'lil-gui';

// Inventaire de public/models dressé au build par le plugin models-manifest (voir vite.config.js)
import fichiersObj from 'virtual:models';

import vertexShader from './vertex.glsl?raw';
import fragmentShader from './fragment.glsl?raw';

const BELCOUR = 'Belcour-Barla';
const REFERENCE = 'Référence spectrale';

const NATIFS = [ 'sphere', 'cube', 'torus' ];
// Dans la liste, un modèle porte le nom de son fichier sans l'extension
const MODELES = fichiersObj.map( f => f.replace( /\.obj$/i, '' ) );

// Tout modèle chargé est ramené à ce diamètre. Le cadrage de la caméra reste ainsi valable quelle
// que soit l'échelle du .obj, et surtout OBJECT_SIZE dans fragment.glsl reste juste : c'est lui
// qui fixe la taille des paillettes.
const TAILLE_MODELE = 26;

// Deux faces voisines dont les normales s'écartent de moins de cet angle sont lissées ensemble ;
// au-delà, l'arête est tenue pour vive et chaque face garde sa propre normale. Tout lisser en bloc
// arrondirait les coins d'un cube ; ne rien lisser laisse voir chaque facette.
const ANGLE_ARETE_VIVE = THREE.MathUtils.degToRad( 60 );

let camera, scene, renderer, object, controls;
let shader;
let uniforms;

// Les géométries sont gardées en mémoire une fois construites : rebasculer sur un modèle déjà
// vu est instantané, et évite surtout de retélécharger puis reparser un .obj de plusieurs Mo.
const geometries = new Map(); // nom -> Promise< BufferGeometry >

let demande = 0; // un .obj se charge de façon asynchrone : seule la dernière demande compte

let settings = {
	modele: 'torus',
	mode: BELCOUR,
	e: 8,
	n2: 1.33,
	C2: 0.01,
	thickness: 380,
	numberOfWaves: 32,
	saturation: 1,
	// La réflectance iridescente vaut ~0.15 : sans exposition l'objet serait très sombre.
	exposure: 12,
	// Fraction de la source ponctuelle reçue par les faces qu'elle n'éclaire pas. Au-delà de
	// ~0.3 l'ambiante prend le dessus et le relief donné par le lobe spéculaire s'aplatit.
	ambient: 0.03,
	// Réflectance de la couche du dessous. Contre-intuitivement, un fond TRÈS réfléchissant
	// (proche du blanc) tue les couleurs : les deux ondes qui interfèrent ont alors des
	// amplitudes très déséquilibrées, donc des franges peu visibles. Mesuré : #f2f2f2 donne
	// un chroma de 0.19 (gris), #6c6c6c le maximise à 0.87.
	baseF0: '#6c6c6c',
	lightPos: { x: 30, y: 30, z: 30 },
	glitterAmount: 0.05,
	glitterVariance: 0.3,
	glitterSize: 800,
};

init();
initGui();
animate();
setGeometry( settings.modele );

// Les .obj partent en tâche de fond dès le chargement de la page : le premier rendu n'attend
// rien, et le temps de dérouler la liste ils sont déjà prêts. loadGeometry() mémorise la
// promesse, donc choisir un modèle en cours de route se raccroche au téléchargement en vol.
for ( const modele of MODELES ) {
	loadGeometry( modele ).catch( error => console.error( `Modèle « ${ modele } » illisible`, error ) );
}

function initGui() {
	const gui = new GUI();

	// Tous les curseurs ne font que recopier settings[clé] dans uniforms[clé]
	const bind = ( key, label, min, max, step ) => {
		const ctrl = gui.add( settings, key ).name( label ).min( min ).max( max );
		if ( step !== undefined ) ctrl.step( step );
		return ctrl.onChange( value => { uniforms[ key ].value = value; } );
	};

	bind( 'e', "Exposant", 1, 20 );
	bind( 'n2', "Indice n2", 1, 2 );
	bind( 'thickness', "Épaisseur (nm)", 100, 1000 );
	bind( 'saturation', "Saturation", 0, 3, 0.01 );
	bind( 'exposure', "Exposition", 0, 20, 0.01 );
	bind( 'ambient', "Ambiante", 0, 1, 0.01 );
	bind( 'glitterAmount', "Paillettes", 0, 1, 0.01 );
	bind( 'glitterVariance', "Variance des paillettes", 0, 1, 0.01 );
	bind( 'glitterSize', "Finesse des paillettes", 1, 1000, 1 );

	// Ces deux-là n'ont de sens que pour l'intégration explicite : la forme analytique suppose
	// une différence de marche indépendante de λ, donc un milieu non dispersif.
	const cauchy = bind( 'C2', "Constante de Cauchy C2", 0, 2 );
	const waves = bind( 'numberOfWaves', "Nombre de longueurs d'onde", 1, 128, 1 );

	gui.add( settings, 'mode', [ BELCOUR, REFERENCE ] ).name( "Modèle spectral" ).onChange(
	function ( value ) {
		const reference = value === REFERENCE;
		uniforms.useReference.value = reference;
		cauchy.show( reference );
		waves.show( reference );
	} );

	gui.addColor( settings, 'baseF0' ).name( "Couche réflective" ).onChange(
	function ( value ) {
		uniforms.baseF0.value.set( value );
	} );

	const lumiere = gui.addFolder( "Lumière" );
	for ( const axe of [ 'x', 'y', 'z' ] ) {
		lumiere.add( settings.lightPos, axe ).name( axe.toUpperCase() ).min( -100 ).max( 100 ).onChange(
		function () {
			uniforms.lightPos.value.copy( settings.lightPos );
		} );
	}

	gui.add( settings, 'modele', [ ...NATIFS, ...MODELES ] ).name( "Modèle" ).onChange( setGeometry );

	cauchy.show( settings.mode === REFERENCE );
	waves.show( settings.mode === REFERENCE );
}

function createGeometry( modele ) {
	switch (modele) {
	case 'cube':
		return new THREE.BoxGeometry( 16, 16, 16 );
	case 'torus':
		return new THREE.TorusKnotGeometry( 10, 3, 400, 64 );
	case 'sphere':
	default:
		return new THREE.SphereGeometry( 13, 64, 32 );
	}
}

function loadGeometry( modele ) {
	if ( ! geometries.has( modele ) ) {
		geometries.set( modele, NATIFS.includes( modele )
			? Promise.resolve( createGeometry( modele ) )
			: lireObj( modele ) );
	}
	return geometries.get( modele );
}

async function lireObj( modele ) {
	const obj = await new OBJLoader().loadAsync( `models/${ modele }.obj` );

	// Un .obj peut contenir plusieurs groupes : on les fusionne pour n'avoir qu'un seul maillage.
	const parties = [];
	obj.traverse( function ( child ) {
		if ( child.isMesh ) parties.push( normaliser( child.geometry ) );
	} );
	if ( parties.length === 0 ) throw new Error( `${ modele }.obj ne contient aucun maillage` );

	const geometry = parties.length > 1 ? mergeGeometries( parties ) : parties[ 0 ];

	// Un .obj arrive à une échelle et une origine quelconques — apple.obj culmine à y ≈ 200.
	geometry.center();
	geometry.computeBoundingSphere();
	const echelle = TAILLE_MODELE / ( 2 * geometry.boundingSphere.radius );
	geometry.scale( echelle, echelle, echelle );

	// Les normales sont refaites ici, et surtout pas avant la mise à l'échelle : toCreasedNormals
	// regroupe les sommets par position arrondie au centième d'unité, une tolérance qui n'a de sens
	// qu'une fois l'objet ramené à TAILLE_MODELE. Sur un .obj modélisé au millimètre, tout le
	// maillage tomberait dans la même case.
	return toCreasedNormals( geometry, ANGLE_ARETE_VIVE );
}

function normaliser( geometry ) {
	// Le shader n'échantillonne aucune texture, et repère les paillettes en espace objet : les UV
	// ne servent à rien.
	//
	// Les normales partent avec : à défaut de « vn » dans le fichier — apple.obj n'en a aucun —
	// OBJLoader en fabrique une PAR FACE (addFaceNormal), et le maillage ressort facetté quelle
	// que soit sa densité. Les rebâtir sans condition est aussi plus sûr que se fier aux « vn »
	// du fichier, que certains exports écrivent également par face. C'est toCreasedNormals qui
	// s'en charge, en fin de lireObj().
	for ( const attribut of [ 'uv', 'uv1', 'uv2', 'color', 'normal' ] ) geometry.deleteAttribute( attribut );

	// mergeGeometries veut des parties toutes indexées ou toutes non indexées. OBJLoader ne produit
	// que du non-indexé, mais on ne dépend pas de ce détail — et toCreasedNormals dé-indexe de
	// toute façon.
	return geometry.index ? geometry.toNonIndexed() : geometry;
}

async function setGeometry( modele ) {
	const jeton = ++demande;

	let geometry;
	try {
		geometry = await loadGeometry( modele );
	} catch {
		return; // l'erreur a déjà été signalée au préchargement
	}

	if ( jeton !== demande ) return; // un autre modèle a été choisi entre-temps

	scene.remove( object );
	object = new THREE.Mesh( geometry, shader );
	scene.add( object );
}

function init() {
	camera = new THREE.PerspectiveCamera( 45, window.innerWidth / window.innerHeight, .1, 2000 );
	camera.position.z = 50;

	scene = new THREE.Scene();

	// cameraPosition n'est pas déclaré ici : three.js le fournit d'office à tout ShaderMaterial
	uniforms = {
		lightPos: { value: new THREE.Vector3().copy( settings.lightPos ) },
		e: { value: settings.e },
		n2: { value: settings.n2 },
		C2: { value: settings.C2 },
		baseF0: { value: new THREE.Color( settings.baseF0 ) },
		thickness: { value: settings.thickness },
		numberOfWaves: { value: settings.numberOfWaves },
		useReference: { value: settings.mode === REFERENCE },
		saturation: { value: settings.saturation },
		exposure: { value: settings.exposure },
		ambient: { value: settings.ambient },
		glitterAmount: { value: settings.glitterAmount },
		glitterVariance: { value: settings.glitterVariance },
		glitterSize: { value: settings.glitterSize },
	};

	shader = new THREE.ShaderMaterial( {
		vertexShader,
		fragmentShader,
		uniforms,
	} );

	shader.glslVersion = THREE.GLSL3;

	// Géométrie vide : setGeometry() la remplace, éventuellement après un chargement asynchrone
	object = new THREE.Mesh( new THREE.BufferGeometry(), shader );
	scene.add( object );

	renderer = new THREE.WebGLRenderer( { antialias: true } );
	// le shader est lourd en ALU : au-delà de 2 on rend 4 à 9x trop de pixels pour rien
	renderer.setPixelRatio( Math.min( window.devicePixelRatio, 2 ) );
	renderer.setSize( window.innerWidth, window.innerHeight );
	document.body.appendChild( renderer.domElement );

	controls = new OrbitControls( camera, renderer.domElement );
	controls.target.set( 0, 0, 0 );
	controls.enableDamping = true;
	controls.dampingFactor = 0.08;
	controls.minDistance = 20;
	controls.maxDistance = 500;
	controls.update();

	window.addEventListener( 'resize', onWindowResize );
}

function onWindowResize() {
	camera.aspect = window.innerWidth / window.innerHeight;
	camera.updateProjectionMatrix();
	renderer.setSize( window.innerWidth, window.innerHeight );
}

function animate() {
	requestAnimationFrame( animate );
	render();
}

function render() {
	controls.update();

	renderer.render( scene, camera );
}

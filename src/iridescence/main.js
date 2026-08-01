import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GUI } from 'lil-gui';

import vertexShader from './vertex.glsl?raw';
import fragmentShader from './fragment.glsl?raw';

const BELCOUR = 'Belcour–Barla';
const REFERENCE = 'Référence spectrale';

let camera, scene, renderer, object, controls;
let shader;
let uniforms;
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
	exposure: 5,
	// Réflectance de la couche du dessous. Contre-intuitivement, un fond TRÈS réfléchissant
	// (proche du blanc) tue les couleurs : les deux ondes qui interfèrent ont alors des
	// amplitudes très déséquilibrées, donc des franges peu visibles. Mesuré : #f2f2f2 donne
	// un chroma de 0.19 (gris), #6c6c6c le maximise à 0.87.
	baseF0: '#6c6c6c',
	lightPos: { x: 30, y: 30, z: 30 },
};

init();
initGui();
animate();

function initGui() {
	const gui = new GUI();

	// Tous les curseurs ne font que recopier settings[clé] dans uniforms[clé]
	const bind = ( key, label, min, max, step ) => {
		const ctrl = gui.add( settings, key ).name( label ).min( min ).max( max );
		if ( step !== undefined ) ctrl.step( step );
		return ctrl.onChange( value => { uniforms[ key ].value = value; } );
	};

	bind( 'e', "Exposant", 1, 200 );
	bind( 'n2', "Indice n2", 1, 2 );
	bind( 'thickness', "Épaisseur (nm)", 100, 1000 );
	bind( 'saturation', "Saturation", 0, 3, 0.01 );
	bind( 'exposure', "Exposition", 0, 20, 0.01 );

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

	gui.add( settings, 'modele', [ 'sphere', 'cube', 'torus' ] ).name( "Modèle" ).onChange( setGeometry );

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

function setGeometry( modele ) {
	scene.remove( object );
	object.geometry.dispose(); // sinon l'ancienne géométrie reste en mémoire GPU
	object = new THREE.Mesh( createGeometry( modele ), shader );
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
	};

	shader = new THREE.ShaderMaterial( {
		vertexShader,
		fragmentShader,
		uniforms,
	} );

	shader.glslVersion = THREE.GLSL3;

	object = new THREE.Mesh( createGeometry( settings.modele ), shader );
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

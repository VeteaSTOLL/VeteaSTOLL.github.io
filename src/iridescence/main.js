import * as THREE from 'three';
import { GUI } from 'lil-gui';

import vertexShader from './vertex.glsl?raw';
import fragmentShader from './fragment.glsl?raw';

let camera, scene, renderer, object;
let shader;
let uniforms;
let settings = { modele: 'thorus', e: 2, n2: 1.33, C2: 0.01, thickness: 380, numberOfWaves: 32, saturation: 1.4 };

init();
animate();
initGui();

function initGui() {
	const gui = new GUI();
	gui.add(settings, 'e').name("Exposant").min( 1 ).max( 100 ).onChange(
	function ( value ) {
		shader.uniforms.e.value = value;
	} );
	gui.add(settings, 'n2').name("Indice n2").min( 1 ).max( 2 ).onChange(
	function ( value ) {
		shader.uniforms.n2.value = value;
	} );
	gui.add(settings, 'C2').name("Constante de Cauchy C2").min( 0 ).max( 2 ).onChange(
	function ( value ) {
		shader.uniforms.C2.value = value;
	} );
	gui.add(settings, 'thickness').name("Épaisseur (nm)").min( 100 ).max( 1000 ).onChange(
	function ( value ) {
		shader.uniforms.thickness.value = value;
	} );
	gui.add(settings, 'numberOfWaves').name("Nombre de longueurs d'onde").min( 1 ).max( 128 ).step( 1 ).onChange(
	function ( value ) {
		shader.uniforms.numberOfWaves.value = value;
	} );
	gui.add(settings, 'saturation').name("Saturation").min( 0 ).max( 3 ).step( 0.01 ).onChange(
	function ( value ) {
		shader.uniforms.saturation.value = value;
	} );
	gui.add(settings, 'modele', ['sphere', 'cube', 'thorus']).name("Modèle").onChange(
	function ( value ) {
		scene.remove(object);
		object = new THREE.Mesh( createGeometry( value ), shader );
		scene.add(object);
	});
}

function createGeometry( modele ) {
	switch (modele) {
	case 'cube':
		return new THREE.BoxGeometry( 16, 16, 16 );
	case 'thorus':
		return new THREE.TorusKnotGeometry( 10, 3, 1000, 160 );
	case 'sphere':
	default:
		return new THREE.SphereGeometry( 13, 64, 32 );
	}
}

function init() {
	camera = new THREE.PerspectiveCamera( 45, window.innerWidth / window.innerHeight, .1, 2000 );
	camera.position.z = 50;

	scene = new THREE.Scene();

	uniforms = {
		cameraPos: { value: camera.position },
		lightPos: { value: new THREE.Vector3(30, 30, 30) },
		e: { value: settings.e },
		n2: { value: settings.n2 },
		C2: { value: settings.C2 },
		thickness: { value: settings.thickness },
		numberOfWaves: { value: settings.numberOfWaves },
		saturation: { value: settings.saturation },
		t: { value: 0 },
	};

	shader = new THREE.ShaderMaterial( {
		vertexShader,
		fragmentShader,
		uniforms,
	} );

	shader.glslVersion = THREE.GLSL3;

	object = new THREE.Mesh( createGeometry( settings.modele ), shader );
	object.position.set( 0, 0, 0 );
	scene.add( object );

	renderer = new THREE.WebGLRenderer( { antialias: true } );
	renderer.setPixelRatio( window.devicePixelRatio );
	renderer.setSize( window.innerWidth, window.innerHeight );
	document.body.appendChild( renderer.domElement );

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
	const timer = Date.now() * 0.001;
	shader.uniforms.t.value = timer;
	object.rotation.y = timer * 0.3;

	renderer.render( scene, camera );
}

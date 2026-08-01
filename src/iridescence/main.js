import * as THREE from 'three';
import { GUI } from 'lil-gui';

import vertexShader from './vertex.glsl?raw';
import fragmentShader from './fragment.glsl?raw';

let camera, scene, renderer, object;
let shader;
let uniforms;
let settings = { modele: 'sphere', exp: 20, n1: 1, n2: 1.33, thickness: 500 };

init();
animate();
initGui();

function initGui() {
	const gui = new GUI();
	gui.add(settings, 'exp').name("Exposant").min( 1 ).max( 100 ).onChange(
	function ( value ) {
		shader.uniforms.exp.value = value;
	} );
	gui.add(settings, 'n1').name("Indice n1").min( 1 ).max( 2 ).onChange(
	function ( value ) {
		shader.uniforms.n1.value = value;
	} );
	gui.add(settings, 'n2').name("Indice n2").min( 1 ).max( 2 ).onChange(
	function ( value ) {
		shader.uniforms.n2.value = value;
	} );
	gui.add(settings, 'thickness').name("Épaisseur (nm)").min( 100 ).max( 1000 ).onChange(
	function ( value ) {
		shader.uniforms.thickness.value = value;
	} );
	gui.add(settings, 'modele', ['sphere', 'cube', 'thorus']).name("Modèle").onChange(
	function ( value ) {
		scene.remove(object);
		switch (value) {
		case 'sphere':
			object = new THREE.Mesh( new THREE.SphereGeometry( 13, 64, 32 ), shader );
			break;
		case 'cube':
			object = new THREE.Mesh( new THREE.BoxGeometry( 16, 16, 16 ), shader );
			break;
		case 'thorus':
			object = new THREE.Mesh( new THREE.TorusKnotGeometry( 10, 3, 1000, 160 ), shader );
			break;
		}
		scene.add(object);
	});
}

function init() {
	camera = new THREE.PerspectiveCamera( 45, window.innerWidth / window.innerHeight, .1, 2000 );
	camera.position.z = 50;

	scene = new THREE.Scene();

	uniforms = {
		cameraPos: { value: camera.position },
		lightPos: { value: new THREE.Vector3(30, 30, 30) },
		exp: { value: settings.exp },
		n1: { value: settings.n1 },
		n2: { value: settings.n2 },
		thickness: { value: settings.thickness },
		t: { value: 0 },
	};

	shader = new THREE.ShaderMaterial( {
		vertexShader,
		fragmentShader,
		uniforms,
	} );

	shader.glslVersion = THREE.GLSL3;

	object = new THREE.Mesh( new THREE.SphereGeometry( 13, 64, 32 ), shader );
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

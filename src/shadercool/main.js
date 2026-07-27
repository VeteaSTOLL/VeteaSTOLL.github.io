import * as THREE from 'three';
import { GUI } from 'lil-gui';
import { OBJLoader } from 'three/addons/loaders/OBJLoader.js';

import vertexShader from './vertex.glsl?raw';
import fragmentShader from './fragment.glsl?raw';

let camera, scene, renderer, object;
let shader;
let uniforms;
let settings = { exp: 20, baseColor: [.0156,.62,.957], specularColor: [1,1,1], backgroundColor: [0,0,0], metallic: true, roughness: 0, taille: 20, amplitude: 0, vitesse: 15, modele:'thorus', bubble: false, hueChange: .66, transparency: 1};

let tortue, fin;

init();
animate();
initGui();

// Init gui
function initGui() {
	const gui = new GUI();
	gui.add(settings, 'exp').name("Exposant").min( 1 ).max( 100 ).onChange(
	function ( value ) {
		shader.uniforms.exp.value = value;
	} );
	gui.addColor(settings, 'baseColor').name("Couleur base").onChange(
	function ( value ) {
		shader.uniforms.baseColor.value = value;
	} );
	gui.addColor(settings, 'specularColor').name("Couleur reflet").onChange(
	function ( value ) {
		shader.uniforms.specularColor.value = value;
	} );
	gui.addColor(settings, 'backgroundColor').name("Couleur de fond").onChange(
	function ( value ) {
		scene.background = new THREE.Color().fromArray(value);
		shader.uniforms.backgroundColor.value = value;
	} );
	gui.add(settings, 'metallic').name("Métallique").onChange(
	function ( value ) {
		shader.uniforms.metallic.value = value;
	});
	gui.add(settings, 'roughness').name("Roughness").min( 0 ).max( .5 ).onChange(
	function ( value ) {
		shader.uniforms.roughness.value = value;
	} );
	gui.add(settings, 'taille').name("Taille").min( 1 ).max( 100 ).onChange(
	function ( value ) {
		switch (settings.modele) {
		case 'thorus':
			shader.uniforms.W.value = [10 * value, value];
			break;
		case 'cube':
			shader.uniforms.W.value = [value, value];
			break;
		}
	} );
	gui.add(settings, 'amplitude').name("Amplitude").min( 0 ).max( 1 ).onChange(
	function ( value ) {
		shader.uniforms.A.value = value;
	} );
	gui.add(settings, 'vitesse').name("Vitesse").min( 0 ).max( 100 ).onChange(
	function ( value ) {
		shader.uniforms.V.value = value;
	} );
	gui.add(settings, 'modele', [ 'thorus', 'cube', 'sphere', 'tortue', 'fin' ] ).name("Modèle").onChange(
	function ( value ) {
		scene.remove(object);
		switch (value) {
		case 'thorus':
			object = new THREE.Mesh( new THREE.TorusKnotGeometry( 10, 3, 1000, 160 ), shader );
			shader.uniforms.W.value = [10 * settings.taille, settings.taille];
			break;
		case 'cube':
			object = new THREE.Mesh( new THREE.BoxGeometry( 20, 20, 20 ), shader );
			shader.uniforms.W.value = [settings.taille, settings.taille];
			break;
		case 'sphere':
			object = new THREE.Mesh( new THREE.SphereGeometry( 15, 64, 32 ), shader );
			shader.uniforms.W.value = [settings.taille, settings.taille];
			break;
		case 'tortue':
			object = tortue;
			shader.uniforms.W.value = [settings.taille, settings.taille];
			break;
		case 'fin':
			object = fin;
			shader.uniforms.W.value = [settings.taille, settings.taille];
			break;
		}
		scene.add(object);
	});
	gui.add(settings, 'bubble').name("Bulle").onChange(
	function ( value ) {
		shader.uniforms.bubble.value = value;
		shader.depthWrite = !value;
	});
	gui.add(settings, 'hueChange').name("Arc-en-ciel").min( 0 ).max( 2 ).onChange(
	function ( value ) {
		shader.uniforms.hueChange.value = value;
	});
	gui.add(settings, 'transparency').name("Transparence").min( 0 ).max( 5 ).onChange(
	function ( value ) {
		shader.uniforms.transparency.value = value;
	});
}

function init() {
	camera = new THREE.PerspectiveCamera( 45, window.innerWidth / window.innerHeight, .1, 2000 );
	camera.position.y = 0;
	camera.position.z = 50;

	scene = new THREE.Scene();

	const light = new THREE.DirectionalLight(0xffffff, 1);
	light.position.set(10, 10, 10);
	scene.add(light);

	uniforms = {
		lightPos: { value: new THREE.Vector3(30,30,30) },
		cameraPos : { value: camera.position },
		baseColor: { value: [.0156,.62,.957] },
		specularColor: { value: [1,1,1] },
		backgroundColor: { value: [0,0,0] },
		exp: { value: 20},
		envMap: { type: "t", value: new THREE.TextureLoader().load( "textures/envMap.jpg" ) },
		metallic: { value: true },
		roughness: { value: 0 },
		W: { value: [200,20] },
		A: { value: 0 },
		t: { value: 0 },
		V: { value: 15 },
		bubble: { value: false },
		hueChange: { value: .66},
		transparency: { value: 1.},
	};

	shader = new THREE.ShaderMaterial( {
		vertexShader,
		fragmentShader,
			transparent: true,
		depthWrite: true,
		blending: THREE.NormalBlending,
		uniforms: uniforms
	} );

	shader.glslVersion = THREE.GLSL3;

	object = new THREE.Mesh( new THREE.TorusKnotGeometry( 10, 3, 1000, 160 ), shader );

	new OBJLoader().load(
		'models/tortue.obj',
		function ( obj ) {
			obj.traverse(function (child) {
				if (child.isMesh) {
					let geometry = child.geometry;
					geometry.rotateX(-Math.PI / 2);
					tortue = new THREE.Mesh( child.geometry, shader );
					tortue.scale.set(2,2,2);
				}
			});
		},
		function ( xhr ) {
			console.log( ( xhr.loaded / xhr.total * 100 ) + '% loaded' );
		},
		function ( error ) {
			console.log( 'An error happened' );
		}
	);
	new OBJLoader().load(
		'models/fin.obj',
		function ( obj ) {
			obj.traverse(function (child) {
				if (child.isMesh) {
					let geometry = child.geometry;
					geometry.rotateX(-Math.PI / 2);
					fin = new THREE.Mesh( child.geometry, shader );
					fin.scale.set(20,20,20);
				}
			});
		},
		function ( xhr ) {
			console.log( ( xhr.loaded / xhr.total * 100 ) + '% loaded' );
		},
		function ( error ) {
			console.log( 'An error happened' );
		}
	);


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
	const timer = (Date.now() * 0.0003) % 1000;
	shader.uniforms.t.value = timer;
	object.rotation.y = timer%360;

	renderer.render( scene, camera );
}

import * as THREE from 'three';
import { GUI } from 'lil-gui';

import vertexShader from './vertex.glsl?raw';
import fragmentShader from './fragment.glsl?raw';

let camera, scene, renderer, object;
let distance = 1.5;
let shaderMandelbrot;
let uniformsMandelbrot;
let settings = { max_iterations: 250, puissanceCouleur: 2, uvMapping: false, julia: false, cx: .285, cy: .01};

init();
animate();
initGui();

// Init gui
function initGui() {
	const gui = new GUI();
	gui.add( settings, 'max_iterations' ).name("Max iterations").min( 0 ).max( 500 ).onChange(
	function ( value ) {
		shaderMandelbrot.uniforms.maxIterations.value = value;
	} );

	gui.add( settings, 'puissanceCouleur' ).name("Puissance Couleur").min( 1 ).max( 10 ).onChange(
	function ( value ) {
		shaderMandelbrot.uniforms.puissanceCouleur.value = value;
	} );

	gui.add( settings, 'uvMapping' ).name("UV").onChange(
	function ( value ) {
		shaderMandelbrot.uniforms.uvMapping.value = value;
	} );

	gui.add( settings, 'julia' ).name("Julia").onChange(
	function ( value ) {
		shaderMandelbrot.uniforms.julia.value = value;
	} );

	gui.add( settings, 'cx' ).name("Cx").min( -2 ).max( 2 ).onChange(
	function ( value ) {
		shaderMandelbrot.uniforms.C.value[0] = value;
	} );

	gui.add( settings, 'cy' ).name("Cy").min( -2 ).max( 2 ).onChange(
	function ( value ) {
		shaderMandelbrot.uniforms.C.value[1] = value;
	} );
}

function init() {
	camera = new THREE.PerspectiveCamera( 45, window.innerWidth / window.innerHeight, .1, 2000 );
	camera.position.y = 0;

	uniformsMandelbrot = {
		maxIterations : { value : 250 },
		puissanceCouleur : { value : 2. },
		zoom : { value : 1. },
		offset : { value : [0., 0.] },
		size : { value : [1920, 1080] },
		uvMapping : { value : false },
		julia : { value : false },
		C : { value : [.285, .01]},
	};

	scene = new THREE.Scene();

	shaderMandelbrot = new THREE.ShaderMaterial( {
		vertexShader,
		fragmentShader,
		uniforms: uniformsMandelbrot
	} );

	shaderMandelbrot.glslVersion = THREE.GLSL3;

	object = new THREE.Mesh( new THREE.BoxGeometry( 1, 1, 1 ), shaderMandelbrot );
	object.position.set( 0, 0, 0 );
	scene.add( object );

	renderer = new THREE.WebGLRenderer( { antialias: true } );
	renderer.setPixelRatio( window.devicePixelRatio );
	renderer.setSize( window.innerWidth, window.innerHeight );
	shaderMandelbrot.uniforms.size.value = [window.innerWidth, window.innerHeight];
	document.body.appendChild( renderer.domElement );

	window.addEventListener( 'resize', onWindowResize );
}

function onWindowResize() {
	camera.aspect = window.innerWidth / window.innerHeight;
	camera.updateProjectionMatrix();
	renderer.setSize( window.innerWidth, window.innerHeight );
	shaderMandelbrot.uniforms.size.value = [window.innerWidth, window.innerHeight];
}

function animate() {
	requestAnimationFrame( animate );
	render();
}

function render() {
	const timer = Date.now() * 0.0001;
	camera.position.x = Math.cos( timer ) * distance;
	camera.position.z = Math.sin( timer ) * distance;
	camera.lookAt( scene.position );

	renderer.render( scene, camera );
}

document.addEventListener("wheel", function zoom(event) {
	shaderMandelbrot.uniforms.zoom.value += event.deltaY * -0.005 * shaderMandelbrot.uniforms.zoom.value;
	if (shaderMandelbrot.uniforms.zoom.value < 0) {
		shaderMandelbrot.uniforms.zoom.value = 0;
	}
})

let mouse_pressed = false;

document.addEventListener("mousedown", (event) => {
	mouse_pressed = true;
})

document.addEventListener("mousemove", (event) => {
	if (mouse_pressed){
		shaderMandelbrot.uniforms.offset.value[0] -= event.movementX / shaderMandelbrot.uniforms.zoom.value;
		shaderMandelbrot.uniforms.offset.value[1] += event.movementY / shaderMandelbrot.uniforms.zoom.value;
	}
})

document.addEventListener("mouseup", (event) => {
	mouse_pressed = false;
})

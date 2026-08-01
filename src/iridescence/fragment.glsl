in vec2 vUv;
in vec3 vNormal;
in vec3 vWorldPos;

out vec4 outColor;

uniform vec3 cameraPos;
uniform vec3 lightPos;
uniform float e;
// indices de réfractions des milieux au dessus (n1) et en dessous (n2) de la couche semi-transparente [1., 2.]
const float n1 = 1.0003; // air
uniform float n2;
// Constante pour la loi de Cauchy
const float C1 = 0.; // air
uniform float C2;


// épaisseur entre la couche semi-transparente et la couche réflective [100, 1000] (nm)
uniform float thickness;

const float spectrumStart=400., spectrumEnd=800.;
uniform float numberOfWaves;

const float PI = 3.1415926536;

const float magnitude = 1000000.;

float dotProduct2Radiants(float dp) {
	return PI * (1.-dp) / 2.;
}

float trueReflectiveIndex(float n0, float C, float waveLength) {
	return n0 + C * magnitude / (waveLength * waveLength);
}

float refractionAngle(float incidence, float n1, float n2, float waveLength) {
	return trueReflectiveIndex(n1, C1, waveLength) * sin(dotProduct2Radiants(incidence)) / trueReflectiveIndex(n2, C2, waveLength);
}

float interference(float waveLength, float phase) {
	// Donne un scalaire entre 0 et 2 en fonction de si l'interference est constructive ou destructive
	return 2. * abs(cos(PI * phase / (waveLength)));
}

float waveLengthIntensity(float waveLength, float incidence, float n1, float n2, float thickness) {
	float refraction = refractionAngle(incidence, n1, n2, waveLength);
	// en nm
	float phase = 2. * thickness / sqrt(1. - refraction);
	return interference(waveLength, phase);
}

void main() {
	vec3 viewDirection = normalize(cameraPos - vWorldPos);
	vec3 lightDirection = normalize(vWorldPos - lightPos);

	float viewDotNormal = dot(-viewDirection, vNormal);
	vec3 reflection = normalize((-viewDirection)-2.* viewDotNormal * vNormal);

	float intensity = dot(lightDirection, -reflection);
	intensity = pow(clamp(intensity, 0., 1.), e);


	float incidence = dot(-lightDirection, vNormal);

	/*
	float step = (spectrumEnd - spectrumStart) / numberOfWaves;
	for(float l=spectrumStart; l<spectrumEnd; l+=step) { 
		waveLengthIntensity(l, incidence, n1, n2, thickness);
	}
	*/

	float r = waveLengthIntensity(700., incidence, n1, n2, thickness);
	float g = waveLengthIntensity(530., incidence, n1, n2, thickness);
	float b = waveLengthIntensity(465., incidence, n1, n2, thickness);
	vec3 color = vec3(r, g, b);

	outColor = vec4(intensity * color, 1.);
}

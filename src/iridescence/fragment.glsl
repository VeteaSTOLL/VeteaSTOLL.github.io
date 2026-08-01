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

const float spectrumStart=380., spectrumEnd=780.;
uniform float numberOfWaves;

const float PI = 3.1415926536;

const float magnitude = 1000000.;

// Source - https://stackoverflow.com/a/14917481
// Posted by Tarc, modified by community. See post 'Timeline' for change history
// Retrieved 2026-07-31, License - CC BY-SA 4.0

const float Gamma = 0.80;

// Taken from Earl F. Glynn's web page:
// http://www.efg2.com/Lab/ScienceAndEngineering/Spectra.htm
vec3 waveLengthToRGB(float Wavelength) {
	vec3 rgb;

	if((Wavelength >= 380.) && (Wavelength < 440.)) {
		rgb = vec3(-(Wavelength - 440.) / (440. - 380.), 0., 1.);
	} else if((Wavelength >= 440.) && (Wavelength < 490.)) {
		rgb = vec3(0., (Wavelength - 440.) / (490. - 440.), 1.);
	} else if((Wavelength >= 490.) && (Wavelength < 510.)) {
		rgb = vec3(0., 1., -(Wavelength - 510.) / (510. - 490.));
	} else if((Wavelength >= 510.) && (Wavelength < 580.)) {
		rgb = vec3((Wavelength - 510.) / (580. - 510.), 1., 0.);
	} else if((Wavelength >= 580.) && (Wavelength < 645.)) {
		rgb = vec3(1., -(Wavelength - 645.) / (645. - 580.), 0.);
	} else if((Wavelength >= 645.) && (Wavelength < 781.)) {
		rgb = vec3(1., 0., 0.);
	} else {
		rgb = vec3(0.);
	}

	return pow(rgb, vec3(Gamma));
}

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

	float lightItensity = dot(lightDirection, -reflection);
	lightItensity = pow(clamp(lightItensity, 0., 1.), e);


	float incidence = dot(-lightDirection, vNormal);

	vec3 finalColor = vec3(0.);
	float waveStep = (spectrumEnd - spectrumStart) / numberOfWaves;
	for(float l=spectrumStart; l<spectrumEnd; l+=waveStep) {
		float I = waveLengthIntensity(l, incidence, n1, n2, thickness);
		finalColor += waveLengthToRGB(l) * I / numberOfWaves;
	}
	
	outColor = vec4(lightItensity * finalColor, 1.);
}

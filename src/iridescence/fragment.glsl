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

// 1. = rendu physique non retouché
uniform float saturation;

const float PI = 3.1415926536;

const float magnitude = 1000000.;

// Approximations analytiques (gaussiennes multi-lobes) des fonctions colorimétriques CIE 1931.
// Source - Chris Wyman, Peter-Pike Sloan, Peter Shirley,
// "Simple Analytic Approximations to the CIE XYZ Color Matching Functions",
// Journal of Computer Graphics Techniques (JCGT), vol. 2, no. 2, 1-11, 2013.
// http://jcgt.org/published/0002/02/01/
vec3 waveLengthToXYZ(float waveLength) {
	float t1, t2, t3;

	t1 = (waveLength - 442.0) * ((waveLength < 442.0) ? 0.0624 : 0.0374);
	t2 = (waveLength - 599.8) * ((waveLength < 599.8) ? 0.0264 : 0.0323);
	t3 = (waveLength - 501.1) * ((waveLength < 501.1) ? 0.0490 : 0.0382);
	float x = 0.362 * exp(-0.5 * t1 * t1) + 1.056 * exp(-0.5 * t2 * t2) - 0.065 * exp(-0.5 * t3 * t3);

	t1 = (waveLength - 568.8) * ((waveLength < 568.8) ? 0.0213 : 0.0247);
	t2 = (waveLength - 530.9) * ((waveLength < 530.9) ? 0.0613 : 0.0322);
	float y = 0.821 * exp(-0.5 * t1 * t1) + 0.286 * exp(-0.5 * t2 * t2);

	t1 = (waveLength - 437.0) * ((waveLength < 437.0) ? 0.0845 : 0.0278);
	t2 = (waveLength - 459.0) * ((waveLength < 459.0) ? 0.0385 : 0.0725);
	float z = 1.217 * exp(-0.5 * t1 * t1) + 0.681 * exp(-0.5 * t2 * t2);

	return vec3(x, y, z);
}

// Matrice XYZ -> sRGB linéaire (primaires sRGB, point blanc D65)
const mat3 XYZ_TO_SRGB = mat3(
	 3.2406, -0.9689,  0.0557,
	-1.5372,  1.8758, -0.2040,
	-0.4986,  0.0415,  1.0570
);

float dotProduct2Radiants(float dp) {
	return PI * (1.-dp) / 2.;
}

float trueReflectiveIndex(float n0, float C, float waveLength) {
	return n0 + C * magnitude / (waveLength * waveLength);
}

// Renvoie sin(θr) via la loi de Snell — pas un angle
float refractionSine(float incidence, float n1, float n2, float waveLength) {
	return trueReflectiveIndex(n1, C1, waveLength) * sin(dotProduct2Radiants(incidence)) / trueReflectiveIndex(n2, C2, waveLength);
}

float interference(float waveLength, float phase) {
	// Donne un scalaire entre 0 et 2 en fonction de si l'interference est constructive ou destructive
	return 2. * abs(cos(PI * phase / (waveLength)));
}

float waveLengthIntensity(float waveLength, float incidence, float n1, float n2, float thickness) {
	float sinR = refractionSine(incidence, n1, n2, waveLength);
	// max(0.) : garde-fou contre la réflexion totale interne (sinon NaN)
	float cosR = sqrt(max(0., 1. - sinR * sinR));
	// différence de marche, en nm
	float phase = 2. * trueReflectiveIndex(n2, C2, waveLength) * thickness * cosR;
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

	vec3 xyz = vec3(0.);
	float yNorm = 0.;

	float waveStep = (spectrumEnd - spectrumStart) / numberOfWaves;
	for(float l=spectrumStart; l<spectrumEnd; l+=waveStep) {
		vec3 cmf = waveLengthToXYZ(l);
		xyz += cmf * waveLengthIntensity(l, incidence, n1, n2, thickness);
		yNorm += cmf.y;
	}

	// Normalisation par l'intégrale de ȳ : un spectre plat donne Y = 1 (blanc),
	// quels que soient le nombre d'échantillons et les bornes du spectre.
	xyz /= yNorm;

	vec3 rgb = max(XYZ_TO_SRGB * xyz, 0.); // clamp des couleurs hors-gamut sRGB

	float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	rgb = max(mix(vec3(luma), rgb, saturation), 0.);

	rgb *= lightItensity;

	// Encodage sRGB en tout dernier, après l'intégration
	outColor = vec4(pow(rgb, vec3(1./2.2)), 1.);
}

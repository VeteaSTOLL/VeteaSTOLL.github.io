in vec2 vUv;
in vec3 vNormal;
in vec3 vWorldPos;

out vec4 outColor;

uniform vec3 cameraPos;
uniform vec3 lightPos;
uniform float e;
// indices de réfractions des milieux au dessus (n1) et en dessous (n2) de la couche semi-transparente [1., 2.]
uniform float n1, n2;
// épaisseur entre la couche semi-transparente et la couche réflective [100, 1000] (nm)
uniform float thickness;

float refractionAngle(float incidence, float n1, float n2, float waveLength) {
	// changer n1 et n2 pour utiliser la Loi de Cauchy (n = n0 + C / len²)
	return n1 * sin(incidence) / n2;
}

float interference(float waveLength, float phase) {
	// Donne un scalaire entre 0 et 2 en fonction de si l'interference est constructive ou destructive
	// probablement très incorrect.
	float truePhase = mod(phase, waveLength);
	float middlePoint = waveLength / 2.;
	float distanceToMiddle = distance(truePhase, middlePoint) / middlePoint;
	return distanceToMiddle * 2.;
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

	float r = waveLengthIntensity(700., incidence, n1, n2, thickness);
	float g = waveLengthIntensity(530., incidence, n1, n2, thickness);
	float b = waveLengthIntensity(465., incidence, n1, n2, thickness);
	vec3 color = vec3(r, g, b);

	outColor = vec4(intensity * color, 1.);
}

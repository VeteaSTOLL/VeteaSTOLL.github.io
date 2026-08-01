in vec2 vUv;
in vec3 vNormal;
in vec3 vWorldPos;

out vec4 outColor;

uniform vec3 cameraPos;
uniform vec3 lightPos;
uniform float exp;
// indices de réfractions des milieux au dessus (n1) et en dessous (n2) de la couche semi-transparente [1., 2.]
uniform float n1, n2;
// épaisseur entre la couche semi-transparente et la couche réflective [100, 1000] (nm)
uniform float thickness;

float refractionAngle(float incidence, float n1, float n2, int waveLength) {
	return n1 * sin(incidence) / n2;
}

float colorIntensity(float waveLength, float phase) {
	float truePhase = mod(phase, waveLength);
	float middlePoint = waveLength / 2.;
	float distanceToMiddle = distance(truePhase, middlePoint) / middlePoint;
	return distanceToMiddle * 2.;
}

void main() {
	vec3 viewDirection = normalize(cameraPos - vWorldPos);
	vec3 lightDirection = normalize(vWorldPos - lightPos);

	float viewDotNormal = dot(-viewDirection, vNormal);
	vec3 reflection = normalize((-viewDirection)-2.* viewDotNormal * vNormal);

	float intensity = dot(lightDirection, -reflection);
	intensity = pow(clamp(intensity, 0., 1.), exp);


	float incidence = dot(-lightDirection, vNormal);
	float refraction = refractionAngle(incidence, n1, n2, 400);

	// en nm
	float phase = 2. * thickness / (sqrt(1. - refraction));

	outColor = vec4(vec3(intensity) + vec3(incidence, 0., 0.), 1.);
}

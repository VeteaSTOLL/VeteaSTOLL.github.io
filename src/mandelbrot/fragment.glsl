in vec2 vUv;
out vec4 outColor;

uniform int maxIterations;
uniform int puissanceCouleur;
uniform float zoom;
uniform vec2 offset;
uniform vec2 size;
uniform bool uvMapping;

uniform bool julia;
uniform vec2 C;

vec2 newCoords(vec2 Z, vec2 origine){
	vec2 addition;
	if (julia) {
		addition = C;
	} else {
		addition = origine;
	}

	return vec2(Z.x * Z.x - Z.y * Z.y + addition.x, 2. * Z.x * Z.y + addition.y);
}

vec3 getColor(float t){
	int length = 5;
	vec3 colors[] = vec3[] (
		vec3(0., 0., 1.),
		vec3(1., 1., 1.),
		vec3(1., .5, 0.),
		vec3(1., 0., 0.),
		vec3(0., 0., 0.)
	);

	for (int i=0; i<length-1; i++) {
		float threshold = float(i+1) / float(length-1);
		if (t < threshold) {
			float facteur = (t-float(i) / float(length-1)) * float(length - 1);
			return mix(colors[i], colors[i+1], facteur);
		}
	}
}

float newT(float t){
	float polynome = 1.;
	for(int i=0; i<puissanceCouleur; i++){
		polynome *= (t-1.);
	}
	if (mod(float(puissanceCouleur), 2.) == 0.){
		polynome *= -1.;
	}
	polynome += 1.;
	return polynome;
}

vec3 color(vec2 coords) {
	int iterations = 0;
	vec2 temp = coords;

	while (iterations < maxIterations && distance(temp, vec2(0., 0.)) < 2.){
		temp = newCoords(temp, coords);
		iterations += 1;
	}

	float distanceFinale = distance(temp, vec2(0., 0.));
	float prop = float(iterations) / float(maxIterations);

	if (distanceFinale < 2.){
		return vec3(0., 0., 0.);
	} else{
		return getColor(newT(prop));
	}
}

void main() {
	vec2 coords;
	if (uvMapping) {
		coords = (vUv - .5) * 4.;
	} else {
		vec2 pixelCoords = gl_FragCoord.xy - size/2.;
		vec2 screenUvCoords = pixelCoords / min(size[0], size[1]);
		screenUvCoords *= 2.;

		coords = screenUvCoords * 2.;
	}
	coords /= zoom;
	coords += (offset * 4.) / min(size[0], size[1]);
	outColor = vec4(color(coords), 1.);
}

in vec2 vUv;
in vec3 vNormal;
in vec3 vWorldPos;

out vec4 outColor;

uniform vec3 cameraPos;
uniform float t;

void main() {
	// Placeholder: à remplacer par le vrai effet d'iridescence.
	vec3 viewDirection = normalize(cameraPos - vWorldPos);
	float facing = dot(viewDirection, normalize(vNormal));
	outColor = vec4(vec3(facing), 1.);
}

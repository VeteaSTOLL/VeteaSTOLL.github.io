in vec2 vUv;
in vec3 vNormal;
in vec3 vWorldPos;

out vec4 outColor;

uniform vec3 cameraPos;
uniform vec3 lightPos;
uniform float exp;

void main() {
	vec3 viewDirection = normalize(cameraPos - vWorldPos);
	vec3 lightDirection = normalize(vWorldPos - lightPos);

	float viewDotNormal = dot(-viewDirection, vNormal);
	vec3 reflection = normalize((-viewDirection)-2.* viewDotNormal * vNormal);

	float lumiere = dot(lightDirection, -reflection);
	lumiere = pow(clamp(lumiere, 0., 1.), exp);

	outColor = vec4(vec3(lumiere), 1.);
}

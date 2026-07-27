in vec2 vUv;
in vec3 vNormal;
in vec3 vWorldPos;

out vec4 outColor;

uniform vec3 baseColor;
uniform vec3 specularColor;
uniform vec3 backgroundColor;
uniform vec3 lightPos;
uniform vec3 cameraPos;
uniform float exp;
uniform sampler2D envMap;
uniform bool metallic;
uniform float roughness;

uniform bool bubble;
uniform float hueChange;
uniform float transparency;

uniform vec2 W;
uniform float A;
uniform float V;
uniform float t;

vec2 vec2yp(vec3 vect) {
	float PI = 3.1415926535;
	float yaw = atan(vect.x, vect.z); // [-PI, PI]
	float pitch = asin(vect.y);          // [-PI/2, PI/2]
	return vec2(yaw, pitch);
}

vec3 yp2vec(vec2 yp) {
	float cosPitch = cos(yp.y);
	return vec3(
		sin(yp.x) * cosPitch,
		sin(yp.y),
		cos(yp.x) * cosPitch
	);
}

vec2 normal2uv(vec3 normal) {
	float PI = 3.1415926535;
	vec2 yp = vec2yp(normal);
	yp.x /= PI*2.;
	yp.y /= PI;
	yp += .5;
	return yp;
}

vec3 random(vec2 co) {
	float x = fract(sin(dot(co, vec2(127.1, 311.7))) * 43758.5453);
	float y = fract(sin(dot(co, vec2(269.5, 183.3))) * 43758.5453);
	float z = fract(sin(dot(co, vec2(113.5, 271.9))) * 43758.5453);
	return vec3(x, y, z);
}

vec3 vaguelette(vec3 normal, vec2 co, float a, vec2 w, float v){
	vec2 yp = vec2yp(normal);
	yp.x += A * cos(w.x * co.x + t*v);
	yp.y += A * cos(w.y * co.y + t*v);
	return yp2vec(yp);
}

vec3 rgb2hsv(vec3 c) {
	// Pas de moi mais j'ai pas l'auteur

	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	// Algo de Sam Hocevar sur stack overflow

	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main() {
	vec3 newNormal = vaguelette(vNormal, vUv, A, W, V);

	newNormal = mix(newNormal, random(vUv), roughness);

	vec3 viewDirection = normalize(cameraPos - vWorldPos);
	vec3 lightDirection = normalize(vWorldPos - lightPos);

	float viewDotNormal = dot(-viewDirection,newNormal);
	vec3 reflection = normalize((-viewDirection)-2.* viewDotNormal *newNormal);

	float lumiere = dot(lightDirection, -reflection);
	lumiere = pow(clamp(lumiere, 0., 1.), exp);

	float ombre = dot(newNormal, -lightDirection);

	vec3 envMapColor = texture(envMap, normal2uv(reflection)).xyz;

	if (bubble) {
		vec3 HSV = rgb2hsv(envMapColor);
		HSV.x += viewDotNormal * hueChange;
		outColor = vec4(hsv2rgb(HSV) + backgroundColor, min(pow(viewDotNormal+1., transparency), HSV.z));
	} else if (metallic) {
		outColor = vec4(envMapColor*baseColor, 1.);
	} else {
		outColor = vec4((baseColor + specularColor * lumiere) * ombre, 1.);
	}
}

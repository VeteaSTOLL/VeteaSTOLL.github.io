out vec2 vUv;
out vec3 vNormal;
out vec3 vWorldPos;

void main(){
	vUv = uv;
	vNormal = normalize(mat3(modelMatrix) * normal);
	vWorldPos = (modelMatrix * vec4(position, 1.)).xyz;
	gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.);
}

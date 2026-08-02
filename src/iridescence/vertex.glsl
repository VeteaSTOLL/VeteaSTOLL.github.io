out vec3 vObjectPos;
out vec3 vNormal;
out vec3 vWorldPos;

void main(){
	// Les paillettes sont pavées en espace objet, et non en UV : elles restent ainsi solidaires
	// de la surface, et leur forme ne dépend pas du dépliage de la géométrie.
	vObjectPos = position;
	vNormal = normalize(mat3(modelMatrix) * normal);
	vWorldPos = (modelMatrix * vec4(position, 1.)).xyz;
	gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.);
}

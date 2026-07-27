out vec4 vertPos;
out vec2 vUv;

void main(){
	vec4 vertPos4  = projectionMatrix * modelViewMatrix * vec4(position, 1.);
	gl_Position    = vertPos4;
	vertPos = vertPos4;
	vUv = uv;
}

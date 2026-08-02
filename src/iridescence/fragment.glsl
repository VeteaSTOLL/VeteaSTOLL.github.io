in vec3 vNormal;
in vec3 vWorldPos;
in vec3 vObjectPos;

out vec4 outColor;

uniform vec3 lightPos;
uniform float e;

// indices de réfractions des milieux au dessus (n1) et en dessous (n2) de la couche semi-transparente [1., 2.]
const float n1 = 1.0003; // air
uniform float n2;
// Constante pour la loi de Cauchy
const float C1 = 0.; // air
uniform float C2;

// réflectance à incidence normale de la couche réflective du dessous
uniform vec3 baseF0;

// épaisseur entre la couche semi-transparente et la couche réflective [100, 1000] (nm)
uniform float thickness;

const float spectrumStart = 380., spectrumEnd = 780.;
const int MAX_WAVES = 128;
uniform float numberOfWaves;

// true  : intégration spectrale explicite (gère la dispersion de Cauchy, coûteuse)
// false : approximation analytique de Belcour & Barla (coût constant, sans dispersion)
uniform bool useReference;

// 1. = rendu physique non retouché
uniform float saturation;
uniform float exposure;

// intensité de la lumière ambiante, relative à la source ponctuelle
uniform float ambient;

// paillettes
uniform float glitterAmount; // [0, 1] : fraction des cellules qui portent une paillette
uniform float glitterVariance; // [0, 1] : 0 = paillettes alignées sur la surface (invisibles), 1 = orientations quelconques
uniform float glitterSize; // nombre de paillettes en travers de l'objet : plus grand = plus fines

// Diamètre approximatif des géométries de la scène : les natives sont construites à cette
// échelle, et main.js y ramène tout modèle chargé (TAILLE_MODELE). glitterSize garde ainsi la
// même signification quel que soit l'objet affiché.
const float OBJECT_SIZE = 26.;

const float PI = 3.1415926536;


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

// Matrice XYZ -> sRGB linéaire (primaires sRGB, point blanc D65).
// /!\ GLSL construit les mat3 EN COLONNES : cette écriture "transposée" est la bonne.
const mat3 XYZ_TO_SRGB = mat3(
	 3.2406, -0.9689,  0.0557,
	-1.5372,  1.8758, -0.2040,
	-0.4986,  0.0415,  1.0570
);

// Un spectre plat donne XYZ = (1,1,1) : c'est l'illuminant E, pas D65. Passé tel quel dans
// XYZ_TO_SRGB il ressortirait rose (1.205, 0.948, 0.909) au lieu de blanc. Diviser par ce
// vecteur réalise l'adaptation chromatique E -> D65 (von Kries) dans l'espace RGB.
const vec3 FLAT_SPECTRUM_RGB = vec3(1.2048, 0.9484, 0.9087); // = XYZ_TO_SRGB * vec3(1.)


float pow2(float x) { return x * x; }
vec3  pow2(vec3 x)  { return x * x; }

// Loi de Cauchy : n(λ) = n₀ + C / λ², λ en µm
float refractiveIndex(float n0, float C, float waveLength) {
	float um = waveLength * 1e-3;
	return n0 + C / (um * um);
}

// Conversions indice <-> réflectance à incidence normale
float iorToFresnel0(float transmittedIor, float incidentIor) {
	return pow2((transmittedIor - incidentIor) / (transmittedIor + incidentIor));
}
vec3 iorToFresnel0(vec3 transmittedIor, float incidentIor) {
	return pow2((transmittedIor - incidentIor) / (transmittedIor + incidentIor));
}
vec3 fresnel0ToIor(vec3 fresnel0) {
	vec3 sqrtF0 = sqrt(clamp(fresnel0, 0., 0.9999)); // garde-fou contre f0 == 1
	return (vec3(1.) + sqrtF0) / (vec3(1.) - sqrtF0);
}

float fresnelSchlick(float f0, float cosTheta) {
	float f = pow(1. - cosTheta, 5.);
	return f0 * (1. - f) + f;
}
vec3 fresnelSchlick(vec3 f0, float cosTheta) {
	float f = pow(1. - cosTheta, 5.);
	return f0 * (1. - f) + vec3(f);
}


// ---------------------------------------------------------------------------------------------
// Mode « Belcour–Barla » — intégration spectrale analytique
//
// L'astuce : le spectre de réflectance d'une couche mince est une somme de cosinus en OPD/λ,
// dont l'intégrale contre les CMF est la transformée de Fourier de ces CMF évaluée en OPD.
// Coût constant, et le terme gaussien exp(-var·phase²) filtre les hautes fréquences —
// l'anti-aliasing spectral est gratuit.
//
// Contrepartie : ça exige un OPD indépendant de λ, donc PAS de dispersion de Cauchy.
// C2 est ignoré dans ce mode (voir evalSpectralReference pour la version dispersive).
//
// Adapté de three.js (ShaderChunk/iridescence_fragment.glsl.js), d'après
// Laurent Belcour, Pascal Barla, "A Practical Extension to Microfacet Theory for the
// Modeling of Varying Iridescence", ACM TOG 36(4), 2017.
// https://belcour.github.io/blog/research/2017/05/01/brdf-thin-film.html
// ---------------------------------------------------------------------------------------------

// Sensibilités XYZ évaluées dans l'espace de Fourier
vec3 evalSensitivity(float opd, vec3 shift) {
	float phase = 2. * PI * opd * 1.0e-9;
	vec3 val = vec3(5.4856e-13, 4.4201e-13, 5.2481e-13);
	vec3 pos = vec3(1.6810e+06, 1.7953e+06, 2.2084e+06);
	vec3 vr  = vec3(4.3278e+09, 9.3046e+09, 6.6121e+09);

	vec3 xyz = val * sqrt(2. * PI * vr) * cos(pos * phase + shift) * exp(-pow2(phase) * vr);
	xyz.x += 9.7470e-14 * sqrt(2. * PI * 4.5282e+09) * cos(2.2399e+06 * phase + shift.x) * exp(-4.5282e+09 * pow2(phase));
	xyz /= 1.0685e-7; // normalisation par ∫ȳ

	// Même adaptation E -> D65 que dans le mode référence, sans quoi les franges seraient
	// teintées différemment dans les deux modes (le terme continu, lui, est déjà en RGB).
	return (XYZ_TO_SRGB * xyz) / FLAT_SPECTRUM_RGB;
}

vec3 evalIridescence(float outsideIOR, float eta2, float cosTheta1, float filmThickness) {
	// Fait tendre l'indice du film vers celui du milieu extérieur quand l'épaisseur -> 0
	float filmIOR = mix(outsideIOR, eta2, smoothstep(0., 0.03, filmThickness));

	// Loi de Snell, sans trigonométrie : on n'a jamais besoin de l'angle, seulement de son cosinus
	float sinTheta2Sq = pow2(outsideIOR / filmIOR) * (1. - pow2(cosTheta1));
	float cosTheta2Sq = 1. - sinTheta2Sq;
	if (cosTheta2Sq < 0.) return vec3(1.); // réflexion totale interne
	float cosTheta2 = sqrt(cosTheta2Sq);

	// Première interface
	float R12 = fresnelSchlick(iorToFresnel0(filmIOR, outsideIOR), cosTheta1);
	float T121 = 1. - R12;
	// saut de phase de π en cas de réflexion sur un milieu d'indice supérieur
	float phi21 = filmIOR < outsideIOR ? 0. : PI;

	// Deuxième interface
	vec3 baseIOR = fresnel0ToIor(baseF0);
	vec3 R23 = fresnelSchlick(iorToFresnel0(baseIOR, filmIOR), cosTheta2);
	vec3 phi23 = vec3(lessThan(baseIOR, vec3(filmIOR))) * PI;

	// différence de marche, en nm
	float opd = 2. * filmIOR * filmThickness * cosTheta2;
	vec3 phi = vec3(phi21) + phi23;

	// Sommation d'Airy : réflexions internes multiples
	vec3 R123 = clamp(R12 * R23, 1e-5, 0.9999);
	vec3 r123 = sqrt(R123);
	vec3 Rs = pow2(T121) * R23 / (vec3(1.) - R123);

	// Terme m = 0 (composante continue) — déjà neutre en RGB
	vec3 I = R12 + Rs;

	// Termes m > 0 (paires de diracs)
	vec3 Cm = Rs - T121;
	for (int m = 1; m <= 2; ++m) {
		Cm *= r123;
		I += Cm * 2. * evalSensitivity(float(m) * opd, float(m) * phi);
	}

	return max(I, vec3(0.)); // clamp des couleurs hors-gamut sRGB
}


// ---------------------------------------------------------------------------------------------
// Mode « Référence » — intégration spectrale explicite
//
// Même modèle physique qu'evalIridescence (Airy tronquée à m = 2), mais intégrée numériquement
// sur le spectre : la seule différence est analytique vs. numérique, ce qui en fait l'outil de
// validation du mode rapide. Seul mode capable de représenter la dispersion de Cauchy.
// ---------------------------------------------------------------------------------------------
vec3 evalSpectralReference(float cosTheta1, float filmThickness) {
	vec3 baseIOR = fresnel0ToIor(baseF0);

	// L'OPD peut varier de plusieurs λ d'un pixel au suivant : le cosinus des franges est alors
	// échantillonné très au-delà de Nyquist (moiré arc-en-ciel). On mesure sa variation
	// pixel-à-pixel une fois à 550 nm — fwidth() exige un flot de contrôle uniforme, donc hors
	// de la boucle — et on l'applique proportionnellement à chaque λ : la variation étant quasi
	// entièrement géométrique, c'est exact au premier ordre.
	float nRef = refractiveIndex(n2, C2, 550.);
	float cosRefSq = 1. - pow2(refractiveIndex(n1, C1, 550.) / nRef) * (1. - pow2(cosTheta1));
	float opdRef = 2. * nRef * filmThickness * sqrt(max(0., cosRefSq));
	float widthScale = fwidth(opdRef) / max(opdRef, 1e-4);

	vec3 xyz = vec3(0.);
	vec3 cmfSum = vec3(0.);

	float waveStep = (spectrumEnd - spectrumStart) / numberOfWaves;
	int waveCount = int(numberOfWaves);

	for (int i = 0; i < MAX_WAVES; ++i) {
		if (i >= waveCount) break;

		// milieu du bin, et non son bord gauche : sinon biais systématique d'un demi-pas
		float l = spectrumStart + (float(i) + 0.5) * waveStep;
		vec3 cmf = waveLengthToXYZ(l);
		cmfSum += cmf;

		float filmIOR = refractiveIndex(n2, C2, l);
		float eta = refractiveIndex(n1, C1, l) / filmIOR;
		float cosTheta2Sq = 1. - pow2(eta) * (1. - pow2(cosTheta1));
		if (cosTheta2Sq < 0.) { xyz += cmf; continue; } // réflexion totale interne
		float cosTheta2 = sqrt(cosTheta2Sq);

		float R12 = fresnelSchlick(iorToFresnel0(filmIOR, n1), cosTheta1);
		float T121 = 1. - R12;
		float phi21 = filmIOR < n1 ? 0. : PI;

		vec3 R23 = fresnelSchlick(iorToFresnel0(baseIOR, filmIOR), cosTheta2);
		vec3 phi23 = vec3(lessThan(baseIOR, vec3(filmIOR))) * PI;

		float opd = 2. * filmIOR * filmThickness * cosTheta2;
		vec3 phi = vec3(phi21) + phi23;

		vec3 R123 = clamp(R12 * R23, 1e-5, 0.9999);
		vec3 r123 = sqrt(R123);
		vec3 Rs = pow2(T121) * R23 / (vec3(1.) - R123);

		vec3 I = R12 + Rs;

		float omega = 2. * PI / l;
		vec3 Cm = Rs - T121;
		for (int m = 1; m <= 2; ++m) {
			Cm *= r123;
			float mOmega = float(m) * omega;
			// moyenner cos(ω·x) sur une largeur w le multiplie par sinc(ω·w/2)
			float x = 0.5 * mOmega * opd * widthScale;
			float damp = x > 1e-4 ? sin(x) / x : 1.;
			I += Cm * 2. * damp * cos(mOmega * opd + float(m) * phi);
		}

		xyz += cmf * max(I, vec3(0.));
	}

	// Normalisation par les trois intégrales de CMF plutôt que par la seule intégrale de ȳ :
	// un spectre plat donne (1,1,1) exact, quels que soient le nombre d'échantillons et les
	// bornes du spectre. Puis adaptation E -> D65, sans quoi ce blanc ressortirait rose.
	vec3 xyzNorm = xyz / max(cmfSum, vec3(1e-4));
	return (XYZ_TO_SRGB * xyzNorm) / FLAT_SPECTRUM_RGB;
}


// Approximation filmique ACES, Krzysztof Narkowicz
// https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
vec3 toneMapACES(vec3 x) {
	return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0., 1.);
}

// Fonction de transfert sRGB exacte (segment linéaire près de 0), et non un simple gamma 2.2
vec3 linearToSRGB(vec3 c) {
	c = max(c, 0.);
	return mix(12.92 * c, 1.055 * pow(c, vec3(1. / 2.4)) - 0.055, step(0.0031308, c));
}

// ---------------------------------------------------------------------------------------------
// Paillettes — pavage de Voronoï en espace objet
//
// Une grille régulière en UV donne des paillettes carrées, et étirées partout où la
// paramétrisation l'est — le nœud de tore, dont les UV s'enroulent le long du tube, en est un
// cas d'école. On partitionne donc l'espace 3D en cellules de Voronoï : la trace d'un polyèdre
// de Voronoï sur la surface est un polygone irrégulier, et sa taille ne dépend que de la
// distance entre germes. Forme et échelle deviennent donc indépendantes du dépliage UV.
// ---------------------------------------------------------------------------------------------

// Hash 3D -> 3D sans sinus.
// Source - Dave Hoskins, "Hash without Sine", https://www.shadertoy.com/view/4djSRW (MIT)
//
// Le hash sin/fract classique s'effondre ici : dot(cellule, vec3(127.1, ...)) atteint plusieurs
// milliers, et un float32 ne garde alors qu'une poignée de bits sous la virgule. sin() y perd
// sa décorrélation et se met à renvoyer des valeurs voisines pour des cellules voisines — d'où
// des amas de paillettes. Le fract() initial ramène tout dans [0,1[ et supprime le problème.
vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

// Coordonnées entières de la cellule de Voronoï contenant p
vec3 voronoiCell(vec3 p) {
	vec3 base = floor(p);
	vec3 nearest = base;
	float best = 1e9;

	// Le germe le plus proche n'est pas forcément celui de la cellule de grille qui contient p :
	// avec un jitter d'une cellule entière, il faut tester les 27 voisines.
	for (int i = -1; i <= 1; ++i)
	for (int j = -1; j <= 1; ++j)
	for (int k = -1; k <= 1; ++k) {
		vec3 cell = base + vec3(i, j, k);
		vec3 delta = cell + hash33(cell) - p; // germe jitteré à l'intérieur de sa cellule
		float d = dot(delta, delta); // comparer les carrés évite 27 sqrt()
		if (d < best) { best = d; nearest = cell; }
	}

	return nearest;
}


void main() {
	// vNormal est interpolée entre sommets, donc raccourcie : la renormaliser
	vec3 N = normalize(vNormal);

	// Sans paillettes — le cas par défaut — le pavage ne sert à rien. Le test porte sur un
	// uniforme : le branchement est cohérent sur toute la surface, donc gratuit.
	//
	// Pas d'atténuation des paillettes selon leur taille à l'écran : filtrer une paillette en
	// la ramenant vers la normale de la surface la fait purement et simplement disparaître, et
	// comme l'empreinte écran explose aux angles rasants, la densité se mettait à dépendre de
	// l'orientation — d'où des plaques de paillettes sur les faces de face, et rien ailleurs.
	// Le scintillement de loin est le comportement attendu de vraies paillettes.
	if (glitterAmount > 0.) {
		vec3 cellPos = vObjectPos * (glitterSize / OBJECT_SIZE);

		// Un aléa décorrélé du jitter : réutiliser hash33(cell) tel quel lierait l'orientation
		// d'une paillette à sa position dans sa cellule, ce qui biaiserait la forme des
		// cellules retenues.
		vec3 rand = hash33(voronoiCell(cellPos) + 19.19);

		if (rand.x < glitterAmount) {
			// Direction uniforme sur la sphère. normalize() d'un vecteur tiré dans le cube
			// sur-représenterait les diagonales, et alignerait visiblement les paillettes.
			float z = rand.y * 2. - 1.;
			float phi = rand.z * 2. * PI;
			vec3 flakeNormal = vec3(sqrt(1. - z * z) * vec2(cos(phi), sin(phi)), z);

			// Rabattre la direction dans l'hémisphère de N borne l'écart à 90° : à
			// glitterVariance = 1 une paillette peut être perpendiculaire à la surface, jamais
			// retournée vers l'intérieur — où elle ne renverrait de toute façon aucune lumière.
			if (dot(flakeNormal, N) < 0.) flakeNormal = -flakeNormal;

			N = normalize(mix(N, flakeNormal, glitterVariance));
		}
	}

	vec3 V = normalize(cameraPosition - vWorldPos);
	vec3 L = normalize(lightPos - vWorldPos);
	vec3 H = normalize(V + L);

	// La micro-facette qui réfléchit L vers V a pour normale H : l'angle d'incidence sur le
	// film est donc l'angle (V, H) — et non (L, N), qui ne dépendrait pas de la caméra et
	// figerait les couleurs sur la surface.
	float cosTheta1 = clamp(dot(V, H), 0., 1.);

	// Lobe spéculaire Blinn-Phong. L'extinction sur les faces qui ne voient pas la lumière est
	// adoucie : un step() binaire découperait un terminateur net en travers de la géométrie.
	float specular = pow(max(dot(N, H), 0.), e) * smoothstep(0., 0.15, dot(N, L));

	vec3 rgb;
	if (useReference) {
		rgb = evalSpectralReference(cosTheta1, thickness);
	} else {
		rgb = evalIridescence(n1, n2, cosTheta1, thickness);
	}
	rgb *= specular;

	// Lumière ambiante. Le lobe spéculaire est le seul terme du modèle : tout ce qu'il n'atteint
	// pas vaut exactement zéro, d'où des ombres parfaitement noires.
	//
	// L'ambiante arrivant de toutes les directions, celle qui repart vers l'œil est celle
	// réfléchie autour de la normale : l'angle d'incidence sur le film est donc (N, V), et non
	// (V, H) comme pour la source ponctuelle. Ça change tout — avec (V, H) la face à l'ombre
	// serait lavée d'une teinte unique, dictée par une lumière qui ne l'éclaire pas ; avec
	// (N, V) l'irisation continue de tourner avec le point de vue, et le terme de Fresnel déjà
	// présent dans le modèle fait monter la réflectance vers les silhouettes.
	if (ambient > 0.) {
		float cosThetaView = clamp(dot(N, V), 0., 1.);

		vec3 ambientRgb;
		if (useReference) {
			ambientRgb = evalSpectralReference(cosThetaView, thickness);
		} else {
			ambientRgb = evalIridescence(n1, n2, cosThetaView, thickness);
		}

		rgb += ambientRgb * ambient;
	}

	// Saturation et exposition sont linéaires : les appliquer après la somme plutôt que sur le
	// seul terme direct laisse le rendu inchangé à ambient = 0, et traite les deux termes pareil.
	float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	rgb = max(mix(vec3(luma), rgb, saturation), 0.);

	rgb *= exposure;

	// Sans tone mapping, le cœur du highlight — là où on veut justement voir la couleur —
	// écrêterait en blanc.
	rgb = toneMapACES(rgb);

	// Encodage sRGB en tout dernier, après l'intégration
	outColor = vec4(linearToSRGB(rgb), 1.);
	// outColor = vec4(N, 1.);
}

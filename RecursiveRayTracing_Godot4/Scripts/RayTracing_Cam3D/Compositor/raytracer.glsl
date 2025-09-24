#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

//Variaveis Globais
const float infinity = 1. / 0.;
const float PI = 3.1415;
const int CheckerPattern = 1;
const int InvisibleLightSource = 2;
layout(rgba16f, binding = 0, set = 0) uniform image2D screen_tex;

layout(rgba16f, binding = 1, set = 0) uniform image2D accum_tex;

// Atribuindo valores do buffer a locais
layout(push_constant) uniform Params{
	vec2 screen_size;
	int NumRenderedFrames;
	bool accumulate;
	bool useSky;
	int MaxBounceCount;
	int NumRayPerPixel;
	int NumMeshes;
	int NumberSpheres;
	float DefocusStrength;
	float DivergeStrength;
}p;

// Buffer Params (push_constant)
int NumRenderedFrames = p.NumRenderedFrames;
int MaxBounceCount = p.MaxBounceCount;
int NumRayPerPixel = p.NumRayPerPixel;
int NumMeshes = p.NumMeshes;
int NumberSpheres = p.NumberSpheres;

//Dados da Camera
layout(set = 0, binding = 2, std430) restrict buffer CameraData {
	mat4 cam_transf;  //Local para Mundo
	vec3 origem;      //Posicao da camera no mundo
	vec3 viewparams;  //Largura, Altura e Z_near
}cam;

// Buffer CameraData
uvec2 screen_size = uvec2(p.screen_size);
vec3 view = cam.viewparams;
vec3 c_origem = cam.origem;
mat4 transf = cam.cam_transf;

//Dados dos objetos
struct RayTracingMaterial {
	vec4 color;
	vec4 emissionColour;
	vec4 specularColour;
	float roughness;
	float emissionStrength;
	float specularProbability;
	int flag;
};

struct Sphere {
	vec3 position;
	float radius;
	RayTracingMaterial material;
};

layout(std430, binding = 3) readonly buffer SphereBuffer {
	Sphere spheres[];
};

struct Triangle{
	vec3 posA, posB, posC;
	vec3 normalA, normalB, normalC;
};

layout(std430, binding = 4) readonly buffer TriangleBuffer {
	Triangle triangles[];
};

struct MeshInfo{
	int firstTriangleIndex;
	int numTriangles;
	vec3 boundMin;
	vec3 boundMax;
	RayTracingMaterial material;
};

layout(std430, binding = 5) readonly buffer MeshBuffer {
	MeshInfo allMeshInfo[];
};

layout(set = 0, binding = 6, std430) restrict buffer SkyData {
	vec4 GroundColour;
	vec4 ColourHorizon;
	vec4 ColourZenith;
	vec3 SunLightDirection;
	int SunFocus;
	int SunIntensity;
}sky;

//Dados do raio
struct Ray {
	vec3 origem;
	vec3 dir;
};

struct HitInfo{
	bool didHit;
	float dst;
	vec3 hitPoint;
	vec3 normal;
	RayTracingMaterial material;
};

//Calcula intercecao de raio com esfera
HitInfo RaySphere(in Ray ray, in vec3 sphereCentre, in float sphereRadius){
	HitInfo hitInfo = HitInfo(false, infinity, vec3(0.0), vec3(0.0), RayTracingMaterial(vec4(0.0), vec4(0.0), vec4(0.0), 0.0, 0.0, 0.0, 0));
	
	vec3 offsetRayOrigin = ray.origem - sphereCentre;
	
	float a = dot(ray.dir, ray.dir);
	float b = 2.0 * dot(offsetRayOrigin, ray.dir);
	float c = dot(offsetRayOrigin, offsetRayOrigin) - (sphereRadius * sphereRadius);
	
	float discriminant = (b * b) - (4.0 * a * c);
	
	if (discriminant >= 0.0) {
		float dst = (-b - sqrt(discriminant)) / (2.0 * a);
		
		if (dst >= 0.0){
			hitInfo.didHit = true;
			hitInfo.dst = dst;
			hitInfo.hitPoint = ray.origem + ray.dir * dst;
			hitInfo.normal = normalize(hitInfo.hitPoint - sphereCentre);
		}
	}
	return hitInfo;
}

//Calcula intercecao de raio com triangulos
HitInfo RayTriangle(in Ray ray, in Triangle tri){
	HitInfo hitInfo = HitInfo(false, infinity, vec3(0.0), vec3(0.0), RayTracingMaterial(vec4(0.0), vec4(0.0), vec4(0.0), 0.0, 0.0, 0.0, 0));
	
	vec3 edgeAB = tri.posB - tri.posA;
	vec3 edgeAC = tri.posC - tri.posA;
	vec3 normalVector = cross(edgeAB, edgeAC);
	vec3 ao = ray.origem - tri.posA;
	vec3 dao = cross(ao, ray.dir);
	
	float determinant = -dot(ray.dir, normalVector);
	float invDet = 1 / determinant;
	
	float dst = dot(ao, normalVector) * invDet;
	float u = dot(edgeAC, dao) * invDet;
	float v = -dot(edgeAB, dao) * invDet;
	float w = 1 - u - v;
	
	hitInfo.didHit = determinant >= 1e-6 && dst >= 0.0 && u >= 0.0 && v >= 0.0 && w>= 0.0;
	hitInfo.dst = dst;
	hitInfo.hitPoint = ray.origem + ray.dir * dst;
	hitInfo.normal = normalize(tri.normalA * w + tri.normalB * u + tri.normalC * v);
	
	return hitInfo;
}

bool RayBoundingBox(in Ray ray, in vec3 boxMin, in vec3 boxMax) {
	vec3 invDir = 1.0 / ray.dir;
	vec3 tMin = (boxMin - ray.origem) * invDir;
	vec3 tMax = (boxMax - ray.origem) * invDir;
	
	vec3 t1 = min(tMin, tMax);
	vec3 t2 = max(tMin, tMax);
	float tNear = max(max(t1.x, t1.y), t1.z);
	float tFar  = min(min(t2.x, t2.y), t2.z);
	
	return tNear <= tFar && tFar >= 0.0;
}

//Encontra primeiro ponto onde raio colidiu retornando informacoes
HitInfo CalculateRayColision(in Ray ray){
	HitInfo closestHit = HitInfo(false, infinity, vec3(0.0), vec3(0.0), RayTracingMaterial(vec4(0.0), vec4(0.0), vec4(0.0), 0.0, 0.0, 0.0, 0));
	for (int i = 0; i < NumberSpheres; ++i){
		HitInfo hitInfo = RaySphere(ray, spheres[i].position, spheres[i].radius);
		
		if(hitInfo.didHit && hitInfo.dst < closestHit.dst){
			closestHit = hitInfo;
			closestHit.material = spheres[i].material;
		}
	}
	
	for (int meshIndex = 0; meshIndex < NumMeshes; ++meshIndex){
		MeshInfo meshInfo = allMeshInfo[meshIndex];
		if (!RayBoundingBox(ray, meshInfo.boundMin, meshInfo.boundMax)) {
			continue;
		}
		
		for (int i = 0; i < meshInfo.numTriangles; ++i) {
			int triIndex = meshInfo.firstTriangleIndex + i;
			Triangle tri = triangles[triIndex];
			HitInfo triHit = RayTriangle(ray, tri);
			
			if (triHit.didHit && triHit.dst < closestHit.dst) {
				closestHit = triHit;
				closestHit.material = meshInfo.material;
			}
		}
	}
	return closestHit;
}

//Valor pseudo aleatorio para cada pixel
uint NextRandom(inout uint state) {
	state = state * 747796405u + 2891336453u;
	uint result = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	result = (result >> 22u) ^ result;
	return result;
}

float RandomValue(inout uint state){
	return NextRandom(state) / 4294967295.0;
}

//Valor aleatorio na distribuicao normal
float RandomValueNormalDistribuition(inout uint state){
	float theta = 2 * 3.1415926 *  RandomValue(state);
	float rho = sqrt(-2 * log(RandomValue(state)));
	return rho * cos(theta);
}

//Calcula direcao aleatoria
vec3 RandomDirection(inout uint state){
	float x = RandomValueNormalDistribuition(state);
	float y = RandomValueNormalDistribuition(state);
	float z = RandomValueNormalDistribuition(state);
	return normalize(vec3(x,y,z));
}

vec2 RandomPointInCircle(inout uint state)
{
	float angle = RandomValue(state) * 2 * PI;
	vec2 pointOnCircle = vec2(cos(angle), sin(angle));
	return pointOnCircle * sqrt(RandomValue(state));
}

vec3 GetEnviromentLight(in Ray ray){
	float skyGradientT = pow(smoothstep(0, 0.4, ray.dir.y), 0.35);
	vec3 skyGradient = mix(sky.ColourHorizon.xyz, sky.ColourZenith.xyz, skyGradientT);
	float sun = pow(max(0, dot(ray.dir, sky.SunLightDirection)), sky.SunFocus) * sky.SunIntensity;
	
	float groundToSkyT = smoothstep(-0.01, 0, ray.dir.y);
	float sunMask = step(0.0, groundToSkyT);
	return mix(sky.GroundColour.xyz, skyGradient, groundToSkyT) + sun * sunMask;
}

//Funcao de Principal dos Raios
vec3 Trace(in Ray ray, in uint state){
	vec3 incomingLight = vec3(0.0);
	vec3 rayColour = vec3(1.0);
	for(int i = 0; i <= MaxBounceCount; ++i){
		HitInfo hitInfo =  CalculateRayColision(ray);
		
		if(hitInfo.didHit){
			RayTracingMaterial material = hitInfo.material;
			
			if(material.flag == InvisibleLightSource && i == 0){
				ray.origem = hitInfo.hitPoint + ray.dir * 0.001;
				continue;
			} else if(material.flag == CheckerPattern){
				vec2 c = mod(floor(hitInfo.hitPoint.xz), 2.0);
				material.color = c.x == c.y ? material.color : material.emissionColour;
			}
			
			ray.origem = hitInfo.hitPoint;
			vec3 diffuseDir = normalize(hitInfo.normal + RandomDirection(state));
			vec3 specularDir = reflect(ray.dir, hitInfo.normal);
			bool isSpecularBounce = material.specularProbability >= RandomValue(state);
			int Result = int(isSpecularBounce);
			ray.dir = normalize(mix(diffuseDir, specularDir, material.roughness * Result));
			
			vec3 emittedLight = material.emissionColour.xyz * material.emissionStrength;
			incomingLight += emittedLight * rayColour;
			rayColour *= mix(material.color.xyz, material.specularColour.xyz, Result);
			
			float p = max(rayColour.x, max(rayColour.y, rayColour.z));
			if(RandomValue(state) >= p) {
				break;
			}
			rayColour *= 1.0 / p;
			
		}else{
			if (p.useSky) {
				incomingLight += GetEnviromentLight(ray) * rayColour;
			}
			break;
		}
	}
	return incomingLight;
}

void main() {
	uvec2 gid = gl_GlobalInvocationID.xy;
	if (gid.x >= screen_size.x || gid.y >= screen_size.y){
		return;
	}
	
	vec2 uv = (vec2(gid) / screen_size);
	
	// Cria semente para randomizador de raios
	uint rngState = (gid.x + gid.y * screen_size.x) + NumRenderedFrames * 719393;
	
	// Calcular ponto focal
	//1.0 necessario para inversao de UV
	vec3 viewPointlocal = vec3((uv - 0.5), 1.0) * view;
	vec3 viewPoint = vec3(transf * vec4(viewPointlocal, 1.0));
	
	Ray ray;
	vec3 totalIncomingLight = vec3(0.0);
	
	vec3 camRight = transf[0].xyz;
	vec3 camUp = transf[1].xyz;
	float DefocusStrength = p.DefocusStrength;
	float DivergeStrength = p.DivergeStrength;
	
	for(int rayIndex = 0; rayIndex < NumRayPerPixel; ++rayIndex){
		
		vec2 defocusJitter = RandomPointInCircle(rngState) * DefocusStrength / p.screen_size.x;
		ray.origem = c_origem + camRight * defocusJitter.x + camUp * defocusJitter.y;
		
		vec2 jitter = RandomPointInCircle(rngState) * DivergeStrength / p.screen_size.x;
		vec3 jitteredFocusPoint = viewPoint + camRight * jitter.x + camUp * jitter.y;
		
		ray.dir = normalize(jitteredFocusPoint - ray.origem);
		
		totalIncomingLight += Trace(ray, rngState);
	}
	
	vec3 pixelCor = totalIncomingLight / NumRayPerPixel;
	
	vec4 color = vec4(pixelCor.xyz, 1.0);
	
	vec4 display;
	
	if (p.accumulate){
		vec4 oldColor = imageLoad(accum_tex, ivec2(gid));
		imageStore(accum_tex, ivec2(gid), oldColor + color);
		display = clamp( ((oldColor + color) / float(NumRenderedFrames + 1)), 0.0, 1.0);
	}  else {
		display = color;
	}
	
	
	imageStore(screen_tex, ivec2(gid), display);
}

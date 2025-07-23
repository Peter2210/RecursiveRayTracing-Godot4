#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

//Variaveis Globais
const float infinity = 1. / 0.;

layout(rgba16f, binding = 0, set = 0) uniform image2D screen_tex;

layout(rgba16f, binding = 1, set = 0) uniform image2D accum_tex;

layout(push_constant) uniform Params{
	vec2 screen_size;
	float NumRenderedFrames;
	float MaxBounceCount;
	float NumRayPerPixel;
	float NumMeshes;
}p;

//Dados da Camera
layout(set = 0, binding = 2, std430) restrict buffer CameraData {
	mat4 cam_transf;  //Local para Mundo
	vec4 origem;      //Posicao da camera no mundo
	vec4 viewparams;  //Largura, Altura e Z_near
}cam;

layout(set = 0, binding = 3, std430) restrict buffer SceneData {
	float NumberSpheres;
}scene;

//Dados dos objetos (Esfera,)
struct RayTracingMaterial {
	vec4 color;
	vec4 emissionColour;
	float roughness;
	float emissionStrength;
};

struct Sphere {
	vec4 position;
	float radius;
	RayTracingMaterial material;
};

layout(std430, binding = 4) readonly buffer SphereBuffer {
	Sphere spheres[];
};

struct Triangle{
	vec4 posA, posB, posC;
	vec4 normalA, normalB, normalC;
};

layout(std430, binding = 5) readonly buffer TriangleBuffer {
	Triangle triangles[];
};

struct MeshInfo{
	float firstTriangleIndex;
	float numTriangles;
	vec4 boundMin;
	vec4 boundMax;
	RayTracingMaterial material;
};

layout(std430, binding = 6) readonly buffer MeshBuffer {
	MeshInfo allMeshInfo[];
};

layout(set = 0, binding = 7, std430) restrict buffer SkyData {
	vec4 GroundColour;
	vec4 ColourHorizon;
	vec4 ColourZenith;
	vec4 SunLightDirection;
	float SunFocus;
	float SunIntensity;
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
HitInfo RaySphere(in Ray ray, in vec4 sphereCentre, in float sphereRadius, inout HitInfo hitInfo){
	vec3 offsetRayOrigin = ray.origem - sphereCentre.xyz;
	
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
			hitInfo.normal = normalize(hitInfo.hitPoint - sphereCentre.xyz);
		}
	}
	return hitInfo;
}

//Calcula intercecao de raio com triangulos
HitInfo RayTriangle(in Ray ray, in Triangle tri, inout HitInfo hitInfo){
	vec3 edgeAB = tri.posB.xyz - tri.posA.xyz;
	vec3 edgeAC = tri.posC.xyz - tri.posA.xyz;
	vec3 normalVector = cross(edgeAB, edgeAC);
	vec3 ao = ray.origem - tri.posA.xyz;
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
	hitInfo.normal = normalize(tri.normalA.xyz * w + tri.normalB.xyz * u + tri.normalC.xyz * v);
	
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
HitInfo CalculateRayColision(in Ray ray, inout HitInfo closestHit){
	for (int i = 0; i < scene.NumberSpheres; ++i){
		HitInfo hitInfo = HitInfo(false, 0.0, vec3(0.0), vec3(0.0), RayTracingMaterial(vec4(0.0), vec4(0.0), 0.0, 0.0));
		RaySphere(ray, spheres[i].position, spheres[i].radius, hitInfo);
		
		if(hitInfo.didHit && hitInfo.dst < closestHit.dst){
			closestHit = hitInfo;
			closestHit.material = spheres[i].material;
		}
	}
	
	HitInfo triHit = HitInfo(false, 0.0, vec3(0.0), vec3(0.0), RayTracingMaterial(vec4(0.0), vec4(0.0), 0.0, 0.0));
	for (int meshIndex = 0; meshIndex < p.NumMeshes; ++meshIndex){
		MeshInfo meshInfo = allMeshInfo[meshIndex];
		if (!RayBoundingBox(ray, meshInfo.boundMin.xyz, meshInfo.boundMax.xyz)) {
			continue;
		}
		
		for (int i = 0; i < meshInfo.numTriangles; ++i) {
			int triIndex = int(meshInfo.firstTriangleIndex) + i;
			Triangle tri = triangles[triIndex];
			RayTriangle(ray, tri, triHit);
			
			if (triHit.didHit && triHit.dst < closestHit.dst) {
				closestHit = triHit;
				closestHit.material = meshInfo.material;
			}
		}
	}
	return closestHit;
}

//Valor pseudo aleatorio para cada pixel
float RandomValue(inout uint state) {
	state = state * 747796405u + 2891336453u;
	uint result = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	result = (result >> 22u) ^ result;
	return float(result) / 4294967295.0;
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

//Caso direcao invadir interior esfera, simplesmente inverte
vec3  RandomHemisphereDirection(in vec3 normal, inout uint state){
	vec3 dir = RandomDirection(state);
	return dir * sign(dot(normal, dir));
}

vec3 GetEnviromentLight(in Ray ray){
	float skyGradientT = pow(smoothstep(0, 0.4, ray.dir.y), 0.35);
	vec3 skyGradient = mix(sky.ColourHorizon.xyz, sky.ColourZenith.xyz, skyGradientT);
	float sun = pow(max(0, dot(ray.dir, sky.SunLightDirection.xyz)), sky.SunFocus) * sky.SunIntensity;
	
	float groundToSkyT = smoothstep(-0.01, 0, ray.dir.y);
	float sunMask = step(0.0, groundToSkyT);
	return mix(sky.GroundColour.xyz, skyGradient, groundToSkyT) + sun * sunMask;
}

//Funcao de Principal dos Raios
vec3 Trace(in Ray ray, inout uint state){
	vec3 incomingLight = vec3(0.0);
	vec3 rayColour = vec3(1.0);
	for(int i = 0; i <= p.MaxBounceCount; ++i){
		HitInfo hitInfo = HitInfo(false, infinity, vec3(0.0), vec3(0.0), RayTracingMaterial(vec4(0.0), vec4(0.0), 0.0, 0.0));
		CalculateRayColision(ray, hitInfo);
		
		if(hitInfo.didHit){
			RayTracingMaterial material = hitInfo.material;
			
			ray.origem = hitInfo.hitPoint;
			vec3 diffuseDir = normalize(hitInfo.normal + RandomDirection(state));
			vec3 specularDir = reflect(ray.dir, hitInfo.normal);
			ray.dir = mix(specularDir, diffuseDir,material.roughness);
			//ray.dir = normalize(hitInfo.normal + RandomDirection(state));
			
			vec3 emittedLight = material.emissionColour.xyz * material.emissionStrength;
			incomingLight += emittedLight * rayColour;
			rayColour *= material.color.xyz;
		}else{
			//incomingLight += GetEnviromentLight(ray) * rayColour;
			break;
		}
	}
	return incomingLight;
}

void main() {
	uvec2 gid = gl_GlobalInvocationID.xy;
	vec2 uv = (vec2(gid) / p.screen_size);
	
	vec4 view = cam.viewparams;
	vec4 c_origem = cam.origem;
	mat4 transf = cam.cam_transf;
	
	//1.0 necessario para inversao 
	vec4 viewPointlocal = vec4((1.0 - uv - 0.5), 1.0, 1.0) * view;
	vec4 temp = transf * viewPointlocal;
	vec3 viewPoint = vec3(temp.x, temp.y, temp.z);
	
	Ray ray;
	ray.origem = vec3(c_origem.x, c_origem.y, c_origem.z);
	ray.dir = normalize(viewPoint - ray.origem);
	
	uint rngState = gid.x + gid.y * uint(p.screen_size.x);
	
	vec3 totalIncomingLight = vec3(0.0);
	
	for(int rayIndex = 0; rayIndex < p.NumRayPerPixel; ++rayIndex){
		totalIncomingLight += Trace(ray, rngState);
		rngState += uint(p.NumRenderedFrames) * 719393u;
	}
	
	vec3 pixelCor = totalIncomingLight / p.NumRayPerPixel;
	
	vec4 color = vec4(pixelCor.xyz, 1.0);
	
	vec4 accumulatedAverage;
	
	if(p.NumRenderedFrames < 1.0){
		accumulatedAverage = color;
		imageStore(accum_tex, ivec2(gid), accumulatedAverage);
	}else{
		vec4 oldColor = imageLoad(accum_tex, ivec2(gid));
		float weight = 1.0 / float(p.NumRenderedFrames + 1);
		accumulatedAverage = oldColor * (1.0 - weight) + color * weight;
		imageStore(accum_tex, ivec2(gid), accumulatedAverage);
	}	
	
	//vec4 tes = vec4(spheres[0].material.roughness,0,0,1);
	//vec4 tes = spheres[1].material.color;
	//vec4 tes = vec4(spheres[1].material.emissionStrength-15.5,0,0,1);
	//vec4 tes = vec4(spheres[0].material.roughness,spheres[0].material.roughness,spheres[0].material.roughness,1);
	//vec4 tes = vec4(spheres[0].material.roughness,spheres[0].material.roughness,spheres[0].material.roughness,1);
	
	//imageStore(screen_tex, ivec2(gid), tes);
	imageStore(screen_tex, ivec2(gid), accumulatedAverage);
}

#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

//Variaveis Globais
const float infinity = 1. / 0.;

layout(rgba16f, binding = 0, set = 0) uniform image2D screen_tex;

layout(rgba16f, binding = 1, set = 0) uniform image2D accum_tex;

layout(push_constant) uniform Params{
	vec2 screen_size;
	int NumRenderedFrames;
}p;

void main() {
	uvec2 gid = gl_GlobalInvocationID.xy;
	if (gid.x >= uint(p.screen_size.x) || gid.y >= uint(p.screen_size.y)){
		return;
	}
	
	vec4 color = imageLoad(screen_tex, ivec2(gid));
	vec4 oldColor = imageLoad(accum_tex, ivec2(gid));
	float weight = 1.0 / p.NumRenderedFrames + 1;
	vec4 accumulatedAverage = clamp((oldColor * (1.0 - weight) + color * weight), 0.0, 1.0);
	imageStore(accum_tex, ivec2(gid), accumulatedAverage);
	
	imageStore(screen_tex, ivec2(gid), accumulatedAverage);
}

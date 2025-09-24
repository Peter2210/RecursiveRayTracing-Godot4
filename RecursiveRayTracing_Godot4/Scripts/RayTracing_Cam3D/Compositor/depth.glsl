#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(rgba16f, binding = 0, set = 0) uniform image2D screen_tex;

layout(binding = 1, set = 0) uniform sampler2D depth_tex;

layout(push_constant) uniform Params{
	vec2 screen_size;
	float inv_proj_2w;
	float inv_proj_3w;
	float dist;
}p;

void main() {
	uvec2 gid = gl_GlobalInvocationID.xy;
	if (gid.x >= p.screen_size.x || gid.y >= p.screen_size.y){
		return;
	}
	
	vec2 uv = (vec2(gid) / p.screen_size);
	
	float depth = texture(depth_tex, uv).r;
	
	float linear_depth = 1 / (depth * p.inv_proj_2w + p.inv_proj_3w);
	
	linear_depth = clamp(linear_depth / p.dist, 0.0 , 1.0);
	
	vec4 color = vec4(linear_depth, linear_depth, linear_depth, 1.0);
	
	imageStore(screen_tex, ivec2(gid), color);
}

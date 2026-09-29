shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tone : source_color = vec4(1.0,0.25,0.1,1.0);
uniform vec2 forward_axis = vec2(0.0,1.0);
uniform float radius = 4.2;
uniform float half_arc = 3.14159;
uniform float lane_width = 2.0;
uniform int shape = 0;
uniform float progress : hint_range(0.0,1.0) = 0.0;
varying vec2 ground;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { ground=VERTEX.xz; }
void fragment() {
 float along=dot(ground,forward_axis);
 float across=dot(ground,vec2(forward_axis.y,-forward_axis.x));
 float r=length(ground);
 float angle=abs(atan(across,along));
 float grain=noise(ground*5.0+vec2(TIME*0.45,-TIME*0.3));
 float fine=noise(ground*19.0-vec2(TIME*0.8));
 float edge=radius-r;
 if(shape==0 && half_arc<3.13) { edge=min(edge,(half_arc-angle)*r); }
 if(shape==1) { edge=min(lane_width*0.5-abs(across),min(along,radius-along)); }
 if(shape==2) {
  float ray_distance=min(abs(across),min(abs(across*cos(0.22)-along*sin(0.22)),abs(across*cos(0.22)+along*sin(0.22))));
  edge=0.12-ray_distance;
 }
 // The outer lip stays fixed at the gameplay boundary; only its inner glow flickers.
 float rim=exp(-max(edge,0.0)*26.0);
 float ember=exp(-max(edge,0.0)*6.0)*smoothstep(0.28,0.85,grain);
 float fissure=pow(1.0-abs(sin(atan(across,along)*17.0+noise(ground*2.0)*5.0)),18.0);
 float cracks=fissure*smoothstep(0.25,0.85,r/radius)*smoothstep(0.35,0.8,grain)*0.22;
 if(shape>0) { cracks=pow(1.0-abs(sin(along*6.0+grain*4.0)),14.0)*0.09; }
 float pulse=0.8+0.2*sin(TIME*6.0+along*2.0);
 float energy=(rim*0.62+ember*0.3+cracks+fine*0.014)*(0.45+progress*0.65)*pulse;
 ALBEDO=tone.rgb*vec3(1.0+rim*0.5,1.0+rim*0.25,1.0);
 ALPHA=clamp(energy,0.0,0.85);
}

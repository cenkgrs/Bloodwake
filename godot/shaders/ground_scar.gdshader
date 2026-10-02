shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform float age=0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
float fracture(vec2 p){
 vec2 cell=floor(p);vec2 local=fract(p);float first=10.0;float second=10.0;
 for(int y=-1;y<=1;y++){
  for(int x=-1;x<=1;x++){
   vec2 offset=vec2(float(x),float(y));
   vec2 seed=vec2(hash(cell+offset),hash(cell+offset+vec2(47.2,13.7)));
   float d=length(offset+seed-local);
   if(d<first){second=first;first=d;}else{second=min(second,d);}
  }
 }
 return second-first;
}
void fragment(){
 vec2 p=UV*2.0-1.0;float r=length(p);
 float n=noise(p*17.0);
 float branch=fracture(p*3.6+vec2(0.37,0.13));
 float crack=1.0-smoothstep(0.012,0.04,branch);
 float chip=1.0-smoothstep(0.035,0.075,branch);
 float edge=1.0-smoothstep(0.6+n*0.22,0.94,r);
 float crater=exp(-r*7.0)*0.7;
 ALBEDO=mix(vec3(0.24,0.17,0.11),vec3(0.025,0.018,0.012),crack);
 ALPHA=(chip*0.85+crater+n*0.13)*edge*(1.0-smoothstep(1.3,1.9,age));
}

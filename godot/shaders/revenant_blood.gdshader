shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform float progress = 0.0;
float hash(vec2 p) {return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment() {
    vec2 p=UV*2.0-1.0;
    float r=length(p);
    float angle=atan(p.y,p.x);
    float edge=.48+sin(angle*9.0)*.12+sin(angle*17.0+.7)*.06;
    float pool=1.0-smoothstep(edge-.08,edge,r);
    float drops=0.0;
    for(int i=0;i<12;i++) {
        float a=float(i)*2.399;
        vec2 c=vec2(cos(a),sin(a))*(.48+hash(vec2(float(i),3.0))*.35);
        drops+=1.0-smoothstep(.025,.055,length(p-c));
    }
    ALBEDO=vec3(.16,.003,.009);
    ALPHA=clamp(pool*.72+drops*.65,0.0,.82)*(1.0-smoothstep(.55,1.0,progress));
}

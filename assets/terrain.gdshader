shader_type canvas_item;
render_mode unshaded;
uniform vec2 map_cells = vec2(64.0);
uniform vec2 crater_center = vec2(1392.0,1280.0);
uniform float crater_radius = 145.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
vec3 material(float kind) {
	if (kind<0.5) return vec3(0.73,0.43,0.19);
	if (kind<1.5 || (kind>2.5 && kind<3.5)) return vec3(0.46,0.37,0.28);
	if (kind<2.5) return vec3(0.82,0.57,0.28);
	if (kind<4.5) return vec3(0.57,0.45,0.32);
	if (kind<5.5) return vec3(0.39,0.27,0.19);
	return vec3(0.33,0.27,0.21);
}
vec2 stone(vec2 p) {
	vec2 tile=floor(p); vec2 local=fract(p); float first=10.0; float second=10.0;
	float identifier=0.0;
	for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
		vec2 offset=vec2(float(x),float(y));
		vec2 seed=vec2(hash(tile+offset),hash(tile+offset+42.0));
		float distance=length(offset+seed-local);
		if(distance<first) { second=first; first=distance; identifier=hash(tile+offset+19.0); }
		else second=min(second,distance);
	}
	return vec2(second-first,identifier);
}
float kind_at(sampler2D terrain_map, vec2 world) {
	vec2 warp=vec2(noise(world*0.07),noise(world*0.07+91.0))-0.5;
	vec2 cell=(world+warp*18.0)/32.0;
	return floor(texture(terrain_map,(floor(cell)+0.5)/map_cells).r*8.0);
}
void fragment() {
	vec2 world=UV*map_cells*32.0;
	float kind=kind_at(TEXTURE,world);
	vec3 base=material(kind);
	vec3 neighbors=(material(kind_at(TEXTURE,world+vec2(6,0)))+material(kind_at(TEXTURE,world-vec2(6,0)))+material(kind_at(TEXTURE,world+vec2(0,6)))+material(kind_at(TEXTURE,world-vec2(0,6))))*0.25;
	base=mix(base,neighbors,0.34);
	float large=noise(world*0.015);
	float medium=noise(world*0.13);
	float fine=noise(world*0.7);
	float grain=hash(floor(world*1.4));
	float variation=(large-0.5)*0.17+(medium-0.5)*0.065+(fine-0.5)*0.055+(grain-0.5)*0.045;
	float ripple=sin(world.y*0.32+noise(world*0.018)*21.0);
	variation+=ripple*0.016;
	if (kind==1.0 || kind==3.0 || kind==6.0) {
		vec2 rock=stone(world*0.047+noise(world*0.035)*0.9);
		variation+=(rock.y-0.5)*0.075;
		variation-=(1.0-smoothstep(0.0,0.025,rock.x))*0.085;
		variation+=smoothstep(0.025,0.04,rock.x)*(1.0-smoothstep(0.04,0.09,rock.x))*0.02;
		float south=kind_at(TEXTURE,world+vec2(0,7));
		float north=kind_at(TEXTURE,world-vec2(0,5));
		if(south==0.0 || south==2.0) variation-=0.10;
		if(north==0.0 || north==2.0) variation+=0.08;
		float dust=smoothstep(0.38,0.73,noise(world*0.012+13.0));
		base=mix(base,vec3(0.66,0.46,0.26),dust*0.28);
		float ash=smoothstep(0.57,0.76,noise(world*0.008+92.0));
		base=mix(base,vec3(0.35,0.27,0.20),ash*0.38);
	} else {
		float crest=sin(world.y*0.046+noise(world*0.007)*9.0);
		variation+=crest*(kind==2.0?0.065:0.023);
		float mineral=smoothstep(0.64,0.83,noise(world*0.026+63.0));
		base=mix(base,vec3(0.44,0.35,0.26),mineral*0.45);
	}
	if(kind==3.0) {
		float veins=1.0-smoothstep(0.02,0.095,abs(noise(world*0.035)-0.5));
		base=mix(base,vec3(0.21,0.43,0.37),veins*0.26);
	}
	if(kind==5.0) {
		vec2 radial=(world-crater_center)/vec2(crater_radius,crater_radius*0.72);
		float r=length(radial);
		variation-=max(0.0,1.0-r)*0.09;
		variation+=exp(-pow((r-0.8)*11.0,2.0))*0.09;
		variation-=exp(-pow((r-0.66)*16.0,2.0))*0.05;
	}
	COLOR=vec4(base+variation,1.0);
}

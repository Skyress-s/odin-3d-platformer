package lightray

/*
Basic lighting implementation for Raylib. Useful to get quick directional and point lights for rendering.
Based on: raylib [shaders] example - basic lighting (https://www.raylib.com/examples.html)
Usage example:
lr.init_lighting()
defer lr.destroy_lighting()
sun_light := lr.create_light(.DIRECTIONAL, {0, 100, 0}, {-1, -1, 0}, rl.WHITE)
blue_light := lr.create_light(.POINT, {3, 0, 3}, {0, 0, 0}, rl.BLUE)
//When loading model, be sure to add the shader to their material.
my_model.materials[0].shader = lr.lighting.shader
...
rl.ClearBackground(rl.BLACK)
rl.BeginMode3D(camera)
lr.begin_lighting()
{
    //Draw stuff
	rl.DrawCubeV({0, 0, 0}, {1, 1, 1}, rl.RED)
}
lr.end_lighting()
rl.DrawGrid(10, 1)
rl.EndMode3D()
*/

import "core:fmt"
import rl "vendor:raylib"

MAX_LIGHTS :: 8

LightType :: enum {
	DIRECTIONAL = 0,
	POINT       = 1,
}

LightShaderLocations :: struct {
	enabled_loc:  i32,
	type_loc:     i32,
	position_loc: i32,
	target_loc:   i32,
	color_loc:    i32,
}

Light :: struct {
	type:                   LightType,
	enabled:                bool,
	position:               rl.Vector3,
	target:                 rl.Vector3,
	color:                  rl.Color,
	using shader_locations: LightShaderLocations,
}

Lighting :: struct {
	shader:        rl.Shader,
	lights:        [dynamic]^Light,
	ambient_loc:   i32,
	debug_enabled: bool,
}

lighting: ^Lighting

init_lighting :: proc(
	ambient_light_color: rl.Color = rl.WHITE,
	ambient_light_intensity: f32 = 0.3,
) {
	lighting = new(Lighting)
	lighting.shader = rl.LoadShaderFromMemory(LIGHT_VERTEX_SHADER, LIGHT_FRAGMENT_SHADER)
	lighting.ambient_loc = rl.GetShaderLocation(lighting.shader, "ambient")
	lighting.lights = make([dynamic]^Light)
	lighting.debug_enabled = ODIN_DEBUG

	set_ambient_light(ambient_light_color, ambient_light_intensity)
}

destroy_lighting :: proc() {
	for &light in lighting.lights {
		free(light)
	}
	delete(lighting.lights)

	rl.UnloadShader(lighting.shader)
	free(lighting)
}

begin_lighting :: proc(clear_color: rl.Color = rl.BLACK) {
	for &light in lighting.lights {
		update_light_values(lighting.shader, light)
	}
	rl.BeginShaderMode(lighting.shader)
}

end_lighting :: proc() {
	rl.EndShaderMode()

	if (lighting.debug_enabled) {
		for light in lighting.lights {
			rl.DrawSphere(light.position, 0.1, light.color)
		}
	}
}

set_ambient_light :: proc(color: rl.Color, intensity: f32) {
	ambient_color :=
		[4]f32{f32(color.r) / 255, f32(color.g) / 255, f32(color.b) / 255, f32(color.a) / 255} *
		intensity
	rl.SetShaderValue(lighting.shader, lighting.ambient_loc, &ambient_color, .VEC4)
}

create_light :: proc(
	type: LightType,
	position, target: rl.Vector3,
	color: rl.Color,
) -> (
	light: ^Light,
) {
	light = new(Light)
	light_count := len(lighting.lights)
	if light_count < MAX_LIGHTS {
		light.enabled = true
		light.type = type
		light.position = position
		light.target = target
		light.color = color

		light.enabled_loc = rl.GetShaderLocation(
			lighting.shader,
			fmt.ctprintf("lights[%i].enabled", light_count),
		)
		light.type_loc = rl.GetShaderLocation(
			lighting.shader,
			fmt.ctprintf("lights[%i].type", light_count),
		)
		light.position_loc = rl.GetShaderLocation(
			lighting.shader,
			fmt.ctprintf("lights[%i].position", light_count),
		)
		light.target_loc = rl.GetShaderLocation(
			lighting.shader,
			fmt.ctprintf("lights[%i].target", light_count),
		)
		light.color_loc = rl.GetShaderLocation(
			lighting.shader,
			fmt.ctprintf("lights[%i].color", light_count),
		)

		update_light_values(lighting.shader, light)
		append(&lighting.lights, light)
	}

	return
}

@(private)
update_light_values :: proc(shader: rl.Shader, light: ^Light) {
	light := light
	rl.SetShaderValue(shader, light.enabled_loc, &light.enabled, .INT)
	rl.SetShaderValue(shader, light.type_loc, &light.type, .INT)
	rl.SetShaderValue(shader, light.position_loc, &light.position, .VEC3)
	rl.SetShaderValue(shader, light.target_loc, &light.target, .VEC3)

	color := [4]f32 {
		f32(light.color.r) / 255,
		f32(light.color.g) / 255,
		f32(light.color.b) / 255,
		f32(light.color.a) / 255,
	}
	rl.SetShaderValue(shader, light.color_loc, &color, .VEC4)
}


LIGHT_VERTEX_SHADER :: `
#version 330
in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec3 vertexNormal;
in vec4 vertexColor;
uniform mat4 mvp;
uniform mat4 matModel;
uniform mat4 matNormal;
out vec3 fragPosition;
out vec2 fragTexCoord;
out vec4 fragColor;
out vec3 fragNormal;
void main()
{
    fragPosition = vec3(matModel*vec4(vertexPosition, 1.0));
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;
    fragNormal = normalize(vec3(matNormal*vec4(vertexNormal, 1.0)));
    gl_Position = mvp*vec4(vertexPosition, 1.0);
}
`


LIGHT_FRAGMENT_SHADER :: `
#version 330
in vec3 fragPosition;
in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragNormal;
uniform sampler2D texture0;
uniform vec4 colDiffuse;
out vec4 finalColor;
#define     MAX_LIGHTS              8
#define     LIGHT_DIRECTIONAL       0
#define     LIGHT_POINT             1
struct Light {
    int enabled;
    int type;
    vec3 position;
    vec3 target;
    vec4 color;
};
uniform Light lights[MAX_LIGHTS];
uniform vec4 ambient;
uniform vec3 viewPos;
void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);
    vec3 lightDot = vec3(0.0);
    vec3 normal = normalize(fragNormal);
    vec3 viewD = normalize(viewPos - fragPosition);
    vec3 specular = vec3(0.0);
    vec4 tint = colDiffuse * fragColor;
    for (int i = 0; i < MAX_LIGHTS; i++) {
        if (lights[i].enabled == 1) {
            vec3 light = vec3(0.0);
            if (lights[i].type == LIGHT_DIRECTIONAL) {
                light = -normalize(lights[i].target - lights[i].position);
            }
            if (lights[i].type == LIGHT_POINT) {
                light = normalize(lights[i].position - fragPosition);
            }
            float NdotL = max(dot(normal, light), 0.0);
            lightDot += lights[i].color.rgb * NdotL;
            float specCo = 0.0;
            if (NdotL > 0.0) specCo = pow(max(0.0, dot(viewD, reflect(-(light), normal))), 16.0);
            specular += specCo;
        }
    }
    finalColor = (texelColor * ((tint + vec4(specular, 1.0)) * vec4(lightDot, 1.0)));
    finalColor += texelColor * ambient * tint;
}
`

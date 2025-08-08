
#version 330 core

layout (location = 0) in vec3 aPos;
out vec4 vertex_color;

void main() {
    gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1);
    vertex_color = vec4(0.5, 0.9, 0.2, 0.1);
}
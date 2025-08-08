#version 330

out vec4 frag_color;
in vec4 vertex_color;

void main() {
    frag_color = (vec4(1.0, 0.0, 0.0, 1.0) + vertex_color) / 2;
}
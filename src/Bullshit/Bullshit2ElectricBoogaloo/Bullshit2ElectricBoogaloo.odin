package Bullshit

// import "core:fmt"
import "core:c"
import v "vendor:vulkan"
import "vendor:glfw"
import s "../Shapes"
// import runtime "base:runtime"

MAX_FRAMES_IN_FLIGHT :: 2

Context :: struct {
  instance : v.Instance,
  device : v.Device,
  physical_device : v.PhysicalDevice,
  swapchain : Swapchain,
  pipeline : Pipeline,
  queue_indices : [QueueFamily]int,
  queues : [QueueFamily]v.Queue,
  surface : v.SurfaceKHR,
  window : glfw.WindowHandle,
  command_pool : v.CommandPool,
  command_buffers : [MAX_FRAMES_IN_FLIGHT]v.CommandBuffer,
  vertex_buffer : Buffer,
  index_buffer : Buffer,

  image_available : [MAX_FRAMES_IN_FLIGHT]v.Semaphore,
  render_finished : [MAX_FRAMES_IN_FLIGHT]v.Semaphore,
  in_flight : [MAX_FRAMES_IN_FLIGHT]v.Fence,

  curr_frame : u32,
  famebuffer_resized : bool,
}

Buffer :: struct {
  buffer : v.Buffer,
  memory : v.DeviceMemory,
  length : int,
  size : v.DeviceSize,
}

Pipeline :: struct {
  handle : v.Pipeline,
  render_pass : v.RenderPass,
  layout : v.PipelineLayout,
}

QueueFamily :: enum {
  Graphics,
  Present,
}

Swapchain :: struct {
  handle : v.SwapchainKHR,
  images : []v.Image,
  image_views : []v.ImageView,
  format : v.SurfaceFormatKHR,
  extent : v.Extent2D,
  present_mode : v.PresentModeKHR,
  image_count : u32,
  support : SwapchainDetails,
  framebuffers : []v.Framebuffer,
}

SwapchainDetails :: struct{
  capabilities : v.SurfaceCapabilitiesKHR,
  formats : []v.SurfaceFormatKHR,
  present_modes : []v.PresentModeKHR,
}

Vertex :: struct {
  pos : [2]f32,
  color : [3]f32,
}

// investigate if it's necessary to format like this
DEVICE_EXTENSIONS := [?]cstring {
  "V_KHR_Swapchain",
};

VALIDATION_LAYERS := [?]cstring {"V_LAYER_KHRONOS_validation"};

main :: proc() {
  using ctx : Context;
  init_window(&ctx);
  for q in &queue_indices do q = -1;

  vertices := [?]Vertex{
    {{-0.5, -0.5}, {0.0, 0.0, 1.0}},
    {{ 0.5, -0.5}, {1.0, 0.0, 0.0}},
    {{ 0.5,  0.5}, {0.0, 1.0, 0.0}},
    {{-0.5,  0.5}, {1.0, 0.0, 0.0}},
  };

  indices := [?]u16{
    0, 1, 2,
    2, 3, 0,
  };
 
  init_vulkan(&ctx, vertices[:], indices[:]);

  for !glfw.WindowShouldClose(window) 
  { 
    glfw.PollEvents(); 
    draw_frame(&ctx, vertices[:], indices[:]);
  }

  v.DeviceWaitIdle(device);

  deinit_vulkan(&ctx);
  glfw.DestroyWindow(window);
  glfw.Terminate();
}

VERTEX_BINDING := v.VertexInputBindingDescription{
  binding = 0,
  stride = size_of(Vertex),
  inputRate = .VERTEX,
}

VERTEX_ATTRIBUTES := [?]vk.VertexInputAttributeDescription{
  {
    binding = 0,
    location = 0,
  }
};


Header-only Vulkan dependencies for the Vulkan renderer, copied from the LunarG Vulkan SDK 1.4.363.0 (`Include/`):

| Files | Project | License |
|---|---|---|
| `include/vulkan/*.h`, `include/vk_video/*.h` | Vulkan-Headers 1.4.363 (Khronos) | Apache-2.0 OR MIT |
| `include/volk.h`, `include/volk.c` | volk (https://github.com/zeux/volk), header version 363. Header-only use with `VOLK_IMPLEMENTATION` includes `volk.c` | MIT |
| `include/vk_mem_alloc.h` | Vulkan Memory Allocator 3.4.0 (AMD) | MIT |

The Vulkan loader (`vulkan-1.dll` on Windows, `libvulkan.so` on Android) comes from the system and is loaded at
runtime by volk, so nothing here is linked or redistributed as a binary. The license texts are in the header files.

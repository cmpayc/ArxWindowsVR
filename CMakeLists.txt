cmake_minimum_required(VERSION 3.12...3.29)
project(ArxWindows)

# Change CMAKE_LIBRARY_ARCHITECTURE to ensure the right libs are used
if(CMAKE_CL_64)
	set(CMAKE_LIBRARY_ARCHITECTURE "x64")
else()
	set(CMAKE_LIBRARY_ARCHITECTURE "x86")
endif()

set(libs "${CMAKE_CURRENT_LIST_DIR}/libs")
if(ANDROID)
	# Built by android/build-deps.ps1, zlib and Vulkan come with the NDK
	set(CMAKE_PREFIX_PATH
		"${libs}/android-arm64"
		"${libs}/boost"
		"${libs}/glm"
		"${libs}/vulkan"
	)
	# The NDK toolchain only searches the sysroot by default
	list(APPEND CMAKE_FIND_ROOT_PATH ${CMAKE_PREFIX_PATH})
	set(USE_OPENGL OFF CACHE BOOL "" FORCE)
	set(BUILD_TOOLS OFF CACHE BOOL "" FORCE)
	set(BUILD_CRASHHANDLER OFF CACHE BOOL "" FORCE)
	set(BUILD_PROFILER OFF CACHE BOOL "" FORCE)
	set(INSTALL_BLENDER_PLUGIN OFF CACHE BOOL "" FORCE)
	set(INSTALL_SCRIPTS OFF CACHE BOOL "" FORCE)
else()
	set(CMAKE_PREFIX_PATH
		"${libs}/boost"
		"${libs}/freetype"
		"${libs}/glm"
		"${libs}/libepoxy"
		"${libs}/openal"
		"${libs}/openxr"
		"${libs}/sdl"
		"${libs}/vulkan"
		"${libs}/zlib"
	)
endif()

if(DEFINED CMAKE_FIND_ROOT_PATH)
	# Need to be able to find these using absolute paths
	if(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY STREQUAL NEVER)
		set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY LAST)
	endif()
	if(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE STREQUAL NEVER)
		set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE LAST)
	endif()
endif()

set(DATA_FILES "${CMAKE_CURRENT_LIST_DIR}/data")

if(NOT DEFINED BUILD_TESTS)
	# TODO Add CppUnit library
	set(BUILD_TESTS OFF)
endif()

add_subdirectory("arx")

if(ANDROID)
	# The libraries are packaged into the APK by Gradle, see android/app/build.gradle
	return()
endif()

add_custom_target(copy-libs ALL)
foreach(prefix IN LISTS CMAKE_PREFIX_PATH)
	set(libdir "${prefix}/bin/${CMAKE_LIBRARY_ARCHITECTURE}")
	if(IS_DIRECTORY "${libdir}")
		file(GLOB libs RELATIVE "${libdir}" "${libdir}/*")
		foreach(lib IN LISTS libs)
			add_custom_command(
				TARGET copy-libs POST_BUILD
				COMMAND ${CMAKE_COMMAND} -E copy_if_different "${libdir}/${lib}" "$<TARGET_FILE_DIR:arx>/${lib}"
			)
		endforeach()
	endif()
endforeach()

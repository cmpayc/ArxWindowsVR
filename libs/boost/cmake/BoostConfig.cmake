# Minimal config for the headers-only Boost bundled with ArxWindows
# (needed since CMake policy CMP0167 disables the FindBoost module)

get_filename_component(_boost_root "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)

set(Boost_FOUND TRUE)
set(Boost_VERSION "1.76.0")
set(Boost_VERSION_STRING "1.76.0")
set(Boost_VERSION_MACRO 107600)
set(Boost_VERSION_MAJOR 1)
set(Boost_VERSION_MINOR 76)
set(Boost_VERSION_PATCH 0)
set(Boost_INCLUDE_DIR "${_boost_root}/include")
set(Boost_INCLUDE_DIRS "${Boost_INCLUDE_DIR}")
set(Boost_LIBRARIES "")

if(NOT TARGET Boost::headers)
	add_library(Boost::headers INTERFACE IMPORTED)
	set_target_properties(Boost::headers PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${Boost_INCLUDE_DIR}")
endif()
if(NOT TARGET Boost::boost)
	add_library(Boost::boost INTERFACE IMPORTED)
	set_target_properties(Boost::boost PROPERTIES INTERFACE_LINK_LIBRARIES Boost::headers)
endif()

# Only headers are bundled, compiled components are not available
foreach(_comp IN LISTS Boost_FIND_COMPONENTS)
	set(Boost_${_comp}_FOUND FALSE)
	if(Boost_FIND_REQUIRED_${_comp})
		set(Boost_FOUND FALSE)
		set(Boost_NOT_FOUND_MESSAGE "Boost component '${_comp}' is not available (headers-only Boost)")
	endif()
endforeach()

unset(_boost_root)

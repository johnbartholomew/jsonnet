# Debian 10 "Buster" has CMake 3.13; Buster is LTS from Aug 1 2022 to June 30 2024.
# So this seems like a reasonable baseline to use.
cmake_minimum_required(VERSION 3.13)

# ------ User-configurable options.
#
# Use ccmake or cmake-gui to configure these, or set them when first running cmake
# with the -D option.

option(BUILD_JSONNET "Build jsonnet command-line tool." ON)
option(BUILD_JSONNETFMT "Build jsonnetfmt command-line tool." ON)
option(BUILD_TESTS "Build and run jsonnet tests." ON)
option(BUILD_STATIC_LIBS "Build static libraries libjsonnet.a and libjsonnet++.a" ON)
option(BUILD_SHARED_LIBS "Build shared libraries libjsonnet.so and libjsonnet++.so" ON)
option(BUILD_SHARED_BINARIES "Link binaries to the shared libjsonnet instead of the static one." OFF)

option(USE_SYSTEM_JSON "Use the system-provided nlohmann json library" OFF)
option(USE_SYSTEM_RAPIDYAML "Use the system-provided Rapid YAML library" OFF)

# ------ Initial module imports, project setup, etc.

# Discourage in-source builds because they overwrite the hand-written Makefile.
# Use `cmake . -B<dir>` or the CMake GUI to do an out-of-source build.
if (${CMAKE_SOURCE_DIR} STREQUAL ${CMAKE_BINARY_DIR})
    message(WARNING "Out-of-source builds are recommended for this project.")
endif()

# Extract the version from include/libjsonnet.h
set(LIBJSONNET_VERSION_REGEX "#define LIB_JSONNET_VERSION[ \t]+\"v([^\"]+)\"")
file(
    STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/include/libjsonnet.h"
    LIBJSONNET_VERSION_STRING REGEX ${LIBJSONNET_VERSION_REGEX})
string(REGEX REPLACE ${LIBJSONNET_VERSION_REGEX} "\\1" LIBJSONNET_VERSION_STRING "${LIBJSONNET_VERSION_STRING}")

project(
    jsonnet
    VERSION "${LIBJSONNET_VERSION_STRING}"
    HOMEPAGE_URL "https://jsonnet.org"
    LANGUAGES C CXX
)

include(GNUInstallDirs)  # Sets up CMAKE_INSTALL_{BINDIR,LIBDIR,INCLUDEDIR}

enable_testing()

# ------ Compiler configuration
#
# C and C++ compiler configuration.
#
# Use CMake built in configuration where possible, as that should cover a wide variety of compilers.

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)
set(CMAKE_CXX_STANDARD 17)  # C++17 is needed for nested namespace definitions (`namespace jsonnet::internal`)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if((CMAKE_CXX_COMPILER_ID STREQUAL "GNU") OR (CMAKE_CXX_COMPILER_ID STREQUAL "Clang"))
    add_compile_options("-Wall" "-Wextra" "-Woverloaded-virtual" "-pedantic" "-Wno-deprecated-declarations")
endif()

# ------ Source code configuration
#
# List out the sources we actually need to build and their dependencies.

add_executable(to_c_array EXCLUDE_FROM_ALL "stdlib/to_c_array.cpp")
# to_c_array doesn't create the output directory, so we need to create it here.
file(MAKE_DIRECTORY "${PROJECT_BINARY_DIR}/stdlib")
add_custom_command(
    OUTPUT "${PROJECT_BINARY_DIR}/stdlib/std.jsonnet.h"
    COMMAND "$<TARGET_FILE:to_c_array>" "${PROJECT_SOURCE_DIR}/stdlib/std.jsonnet" "${PROJECT_BINARY_DIR}/stdlib/std.jsonnet.h"
    MAIN_DEPENDENCY stdlib/std.jsonnet
    DEPENDS "$<TARGET_FILE:to_c_array>"
    COMMENT "Packing std.jsonnet"
    VERBATIM  # Command arguments should be interpreted verbatim (don't go through the shell)
)

add_library(libjsonnet_obj OBJECT)
target_include_directories(
    libjsonnet_obj
    PUBLIC include
    PRIVATE
        third_party/md5
        "${PROJECT_BINARY_DIR}/stdlib"
)
target_sources(libjsonnet_obj
    PRIVATE
        "${PROJECT_BINARY_DIR}/stdlib/std.jsonnet.h"

        core/desugarer.cpp
        core/formatter.cpp
        core/lexer.cpp
        core/libjsonnet.cpp
        core/parser.cpp
        core/pass.cpp
        core/static_analysis.cpp
        core/string_utils.cpp
        core/vm.cpp

        third_party/md5/md5.cpp
)
# Build with -fPIC regardless of whether we're trying to make a static or shared lib.
# This allows the OBJECT library to be used in the built SHARED libraries.
# It has the disadvantage of applying -fPIC unnecessarily to the static library code.
set_target_properties(libjsonnet_obj PROPERTIES POSITION_INDEPENDENT_CODE ON)

# ------ Third-Party dependencies

if(USE_SYSTEM_JSON)
    find_package(nlohmann_json REQUIRED)
    target_link_libraries(libjsonnet_obj PUBLIC nlohmann_json)
else()
    # It's a header-only library, so no extra files to build just an extra include directory.
    target_include_directories(libjsonnet_obj INTERFACE third_party/json)
endif()

if(USE_SYSTEM_RAPIDYAML)
    find_package(ryml REQUIRED)
    target_link_libraries(libjsonnet_obj PUBLIC ryml)
    target_compile_definitions(libjsonnet_obj PRIVATE "USE_SYSTEM_RAPIDYAML=1")
else()
    # Add the bundled Rapid YAML single translation unit directly to libjsonnet_obj.
    target_compile_definitions(libjsonnet_obj PRIVATE "USE_SYSTEM_RAPIDYAML=0")
    target_sources(libjsonnet_obj PRIVATE third_party/rapidyaml/rapidyaml.cpp)
    target_include_directories(libjsonnet_obj INTERFACE third_party/rapidyaml)
endif()

# ------ Outputs / build target configuration
#
# Specify the actual outputs we care about building.

if(BUILD_SHARED_LIBS OR BUILD_SHARED_BINARIES)
    add_library(libjsonnet_shared SHARED)
    target_link_libraries(libjsonnet_shared PUBLIC libjsonnet_obj)
    add_library(libjsonnetpp_shared SHARED "cpp/libjsonnet++.cpp")
    target_link_libraries(libjsonnetpp_shared PUBLIC libjsonnet_obj)

    set_target_properties(libjsonnet_shared PROPERTIES
        OUTPUT_NAME jsonnet  # The 'lib' prefix is added internally.
	    VERSION "${LIBJSONNET_VERSION_STRING}"
        SOVERSION "0")
    set_target_properties(libjsonnetpp_shared PROPERTIES
        OUTPUT_NAME "jsonnet++"  # The 'lib' prefix is added internally.
	    VERSION "${LIBJSONNET_VERSION_STRING}"
        SOVERSION "0")

    if(BUILD_SHARED_LIBS)
        install(
            TARGETS libjsonnet_shared libjsonnetpp_shared
            LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
            PUBLIC_HEADER DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}")
    endif()
    if(BUILD_SHARED_BINARIES)
        add_library(libjsonnet_for_binaries ALIAS libjsonnet_shared)
    endif()
endif()

if(BUILD_STATIC_LIBS OR (NOT BUILD_SHARED_BINARIES))
    add_library(libjsonnet_static STATIC)
    target_link_libraries(libjsonnet_static PUBLIC libjsonnet_obj)
    add_library(libjsonnetpp_static STATIC "cpp/libjsonnet++.cpp")
    target_link_libraries(libjsonnetpp_static PUBLIC libjsonnet_obj)

    set_target_properties(libjsonnet_static PROPERTIES
        OUTPUT_NAME jsonnet  # The 'lib' prefix is added internally.
	    VERSION "${LIBJSONNET_VERSION_STRING}")
    set_target_properties(libjsonnetpp_static PROPERTIES
        OUTPUT_NAME "jsonnet++"  # The 'lib' prefix is added internally.
	    VERSION "${LIBJSONNET_VERSION_STRING}")

    if(BUILD_STATIC_LIBS)
        install(
            TARGETS libjsonnet_static libjsonnetpp_static
            ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
            PUBLIC_HEADER DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}")
    endif()
    if(NOT BUILD_SHARED_BINARIES)
        add_library(libjsonnet_for_binaries ALIAS libjsonnet_static)
    endif()
endif()

if(BUILD_JSONNET)
    add_executable(jsonnet "cmd/jsonnet.cpp" "cmd/utils.cpp")
    target_link_libraries(jsonnet PRIVATE libjsonnet_for_binaries)
    install(TARGETS jsonnet RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
endif()

if(BUILD_JSONNETFMT)
    add_executable(jsonnetfmt "cmd/jsonnetfmt.cpp" "cmd/utils.cpp")
    target_link_libraries(jsonnetfmt PRIVATE libjsonnet_for_binaries)
    install(TARGETS jsonnetfmt RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
endif()

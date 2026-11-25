# geotiff — dependency-free C++17 GeoTIFF tile reader (static library: one header, one source file).
#
# Standalone:   cmake --preset dev && cmake --build --preset dev && ctest --preset dev
# Consumer:     add_subdirectory(geotiff) / FetchContent, or find_package(geotiff) after install,
#               then  target_link_libraries(app PRIVATE geotiff::geotiff)  and
#               #include "geotiff/geotiff.h".
cmake_minimum_required(VERSION 3.21)

project(geotiff
    VERSION 0.3.0
    DESCRIPTION "Dependency-free C++17 GeoTIFF tile reader (256x256 tiles, GDAL sparse files, no exceptions)"
    LANGUAGES CXX)

include(GNUInstallDirs)

option(GEOTIFF_BUILD_TESTS "Build the geotiff test suite" ${PROJECT_IS_TOP_LEVEL})
option(GEOTIFF_BUILD_EXAMPLES "Build the geotiff example" ${PROJECT_IS_TOP_LEVEL})
option(GEOTIFF_INSTALL "Generate the geotiff install/export rules" ${PROJECT_IS_TOP_LEVEL})
option(GEOTIFF_SANITIZE "Build tests and example with ASan + UBSan" OFF)

# Tile width = height in pixels. Empty = the default of the header (256). The value is a
# PUBLIC definition: the library and everything that links it see the same tile size.
set(GEOTIFF_TILE_SIZE "" CACHE STRING "Tile size the library is built for (empty = header default)")

# Library, tests and example build the way the library promises to work: no exceptions, no RTTI.
function(geotiff_flags name)
    set_target_properties(${name} PROPERTIES CXX_EXTENSIONS OFF)
    if(MSVC)
        target_compile_options(${name} PRIVATE /W4 /GR-)
    else()
        target_compile_options(${name} PRIVATE -Wall -Wextra -pedantic -fno-exceptions -fno-rtti)
        if(GEOTIFF_SANITIZE)
            target_compile_options(${name} PRIVATE
                -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
            target_link_options(${name} PUBLIC -fsanitize=address,undefined)
        endif()
    endif()
endfunction()

# --- library ------------------------------------------------------------------------------
function(geotiff_library name tile_size)
    add_library(${name} STATIC src/geotiff.cpp)
    target_compile_features(${name} PUBLIC cxx_std_17)
    target_include_directories(${name} PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
    if(NOT "${tile_size}" STREQUAL "")
        target_compile_definitions(${name} PUBLIC GEOTIFF_TILE_SIZE=${tile_size})
    endif()
    geotiff_flags(${name})
endfunction()
geotiff_library(geotiff "${GEOTIFF_TILE_SIZE}")
# Not libgeotiff.a: that is the file name of the OSGeo libgeotiff library.
set_target_properties(geotiff PROPERTIES OUTPUT_NAME geotiff_tile_reader)
add_library(geotiff::geotiff ALIAS geotiff)

function(geotiff_program name source library)
    add_executable(${name} ${source})
    target_link_libraries(${name} PRIVATE ${library})
    geotiff_flags(${name})
endfunction()

# --- examples -----------------------------------------------------------------------------
if(GEOTIFF_BUILD_EXAMPLES)
    geotiff_program(geotiff_info examples/geotiff_info.cpp geotiff::geotiff)
endif()

# --- tests --------------------------------------------------------------------------------
if(GEOTIFF_BUILD_TESTS)
    enable_testing()
    # The unit suite twice: with the library as it ships, and with a second build of the
    # library for 16x16 tiles, where the files are small enough to truncate and mutate at
    # every byte.
    geotiff_program(geotiff_test tests/geotiff_test.cpp geotiff::geotiff)
    add_test(NAME geotiff.unit COMMAND geotiff_test)
    geotiff_library(geotiff_small_tiles 16)
    geotiff_program(geotiff_test_small tests/geotiff_test.cpp geotiff_small_tiles)
    add_test(NAME geotiff.unit_small_tiles COMMAND geotiff_test_small)
    add_test(NAME geotiff.no_exceptions
        COMMAND ${CMAKE_COMMAND} -DHEADER=${CMAKE_CURRENT_SOURCE_DIR}/include/geotiff/geotiff.h
                -DSOURCE=${CMAKE_CURRENT_SOURCE_DIR}/src/geotiff.cpp
                -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/check_no_exceptions.cmake)

    add_test(NAME geotiff.knowledge
        COMMAND ${CMAKE_COMMAND} -DHEADER=${CMAKE_CURRENT_SOURCE_DIR}/include/geotiff/geotiff.h
                -DSOURCE=${CMAKE_CURRENT_SOURCE_DIR}/src/geotiff.cpp
                -DTEST=${CMAKE_CURRENT_SOURCE_DIR}/tests/geotiff_test.cpp
                -DKNOWLEDGE=${CMAKE_CURRENT_SOURCE_DIR}/llm/knowledge.md
                -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/check_knowledge.cmake)

    # GDAL oracle — only if a Python 3 with the GDAL bindings (python-gdal) is found:
    # GDAL writes the files and dumps every block with ReadBlock, the reader must agree.
    find_package(Python3 COMPONENTS Interpreter QUIET)
    set(_gdal_missing 1)
    if(Python3_Interpreter_FOUND)
        execute_process(COMMAND ${Python3_EXECUTABLE} -c "from osgeo import gdal"
            RESULT_VARIABLE _gdal_missing OUTPUT_QUIET ERROR_QUIET)
    endif()
    if(_gdal_missing EQUAL 0)
        geotiff_program(geotiff_oracle_check tests/oracle_check.cpp geotiff::geotiff)
        set(_oracle ${CMAKE_CURRENT_BINARY_DIR}/oracle)
        add_test(NAME geotiff.oracle_generate
            COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/tests/oracle_generate.py ${_oracle})
        add_test(NAME geotiff.oracle_check COMMAND geotiff_oracle_check ${_oracle})
        set_tests_properties(geotiff.oracle_generate PROPERTIES FIXTURES_SETUP geotiff_oracle)
        set_tests_properties(geotiff.oracle_check PROPERTIES FIXTURES_REQUIRED geotiff_oracle)
        if(GEOTIFF_BUILD_EXAMPLES)
            add_test(NAME geotiff.example_info COMMAND geotiff_info ${_oracle}/overviews_sparse.tif)
            set_tests_properties(geotiff.example_info PROPERTIES FIXTURES_REQUIRED geotiff_oracle)
        endif()
        message(STATUS "geotiff: GDAL oracle tests enabled (${Python3_EXECUTABLE})")
    else()
        message(STATUS "geotiff: Python GDAL bindings not found — GDAL oracle tests skipped")
    endif()
endif()

# --- install / package config -------------------------------------------------------------
if(GEOTIFF_INSTALL)
    include(CMakePackageConfigHelpers)

    install(TARGETS geotiff EXPORT geotiffTargets)
    install(FILES include/geotiff/geotiff.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/geotiff)
    install(EXPORT geotiffTargets
        NAMESPACE geotiff::
        DESTINATION ${CMAKE_INSTALL_DATADIR}/cmake/geotiff)

    configure_package_config_file(cmake/geotiffConfig.cmake.in
        ${CMAKE_CURRENT_BINARY_DIR}/geotiffConfig.cmake
        INSTALL_DESTINATION ${CMAKE_INSTALL_DATADIR}/cmake/geotiff)
    write_basic_package_version_file(${CMAKE_CURRENT_BINARY_DIR}/geotiffConfigVersion.cmake
        COMPATIBILITY SameMinorVersion)
    install(FILES
        ${CMAKE_CURRENT_BINARY_DIR}/geotiffConfig.cmake
        ${CMAKE_CURRENT_BINARY_DIR}/geotiffConfigVersion.cmake
        DESTINATION ${CMAKE_INSTALL_DATADIR}/cmake/geotiff)
endif()

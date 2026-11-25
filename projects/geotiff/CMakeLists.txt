# geotiff — dependency-free C++17 single-header GeoTIFF block reader.
#
# Standalone:   cmake --preset dev && cmake --build --preset dev && ctest --preset dev
# Consumer:     add_subdirectory(geotiff) / FetchContent, or find_package(geotiff) after install,
#               then  target_link_libraries(app PRIVATE geotiff::geotiff)  and
#               #include "geotiff/geotiff.hpp".
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

# --- library: header-only INTERFACE target --------------------------------------------
add_library(geotiff INTERFACE)
add_library(geotiff::geotiff ALIAS geotiff)
target_compile_features(geotiff INTERFACE cxx_std_17)
target_include_directories(geotiff INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)

# Tests and example build the way the header promises to work: no exceptions, no RTTI.
function(geotiff_program name source)
    add_executable(${name} ${source})
    target_link_libraries(${name} PRIVATE geotiff::geotiff)
    set_target_properties(${name} PROPERTIES CXX_EXTENSIONS OFF)
    if(MSVC)
        target_compile_options(${name} PRIVATE /W4 /GR-)
    else()
        target_compile_options(${name} PRIVATE -Wall -Wextra -pedantic -fno-exceptions -fno-rtti)
        if(GEOTIFF_SANITIZE)
            target_compile_options(${name} PRIVATE
                -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer)
            target_link_options(${name} PRIVATE -fsanitize=address,undefined)
        endif()
    endif()
endfunction()

# --- examples -----------------------------------------------------------------------------
if(GEOTIFF_BUILD_EXAMPLES)
    geotiff_program(geotiff_info examples/geotiff_info.cpp)
endif()

# --- tests --------------------------------------------------------------------------------
if(GEOTIFF_BUILD_TESTS)
    enable_testing()
    # The unit suite twice: with the tile size the header ships with, and with 16x16 tiles,
    # where the files are small enough to truncate and mutate at every byte.
    geotiff_program(geotiff_test tests/geotiff_test.cpp)
    add_test(NAME geotiff.unit COMMAND geotiff_test)
    geotiff_program(geotiff_test_small tests/geotiff_test.cpp)
    target_compile_definitions(geotiff_test_small PRIVATE GEOTIFF_TILE_SIZE=16)
    add_test(NAME geotiff.unit_small_tiles COMMAND geotiff_test_small)
    add_test(NAME geotiff.no_exceptions
        COMMAND ${CMAKE_COMMAND} -DHEADER=${CMAKE_CURRENT_SOURCE_DIR}/include/geotiff/geotiff.hpp
                -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/check_no_exceptions.cmake)

    add_test(NAME geotiff.knowledge
        COMMAND ${CMAKE_COMMAND} -DHEADER=${CMAKE_CURRENT_SOURCE_DIR}/include/geotiff/geotiff.hpp
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
        geotiff_program(geotiff_oracle_check tests/oracle_check.cpp)
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
    install(FILES include/geotiff/geotiff.hpp DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/geotiff)
    install(EXPORT geotiffTargets
        NAMESPACE geotiff::
        DESTINATION ${CMAKE_INSTALL_DATADIR}/cmake/geotiff)

    configure_package_config_file(cmake/geotiffConfig.cmake.in
        ${CMAKE_CURRENT_BINARY_DIR}/geotiffConfig.cmake
        INSTALL_DESTINATION ${CMAKE_INSTALL_DATADIR}/cmake/geotiff)
    write_basic_package_version_file(${CMAKE_CURRENT_BINARY_DIR}/geotiffConfigVersion.cmake
        COMPATIBILITY SameMinorVersion
        ARCH_INDEPENDENT)
    install(FILES
        ${CMAKE_CURRENT_BINARY_DIR}/geotiffConfig.cmake
        ${CMAKE_CURRENT_BINARY_DIR}/geotiffConfigVersion.cmake
        DESTINATION ${CMAKE_INSTALL_DATADIR}/cmake/geotiff)
endif()

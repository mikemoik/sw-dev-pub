# cbor — C++17 single-header CBOR codec (RFC 8949 subset + RFC 8746 typed arrays).
#
# Standalone:   cmake -S . -B build && cmake --build build && ctest --test-dir build
# Consumer:     add_subdirectory(cbor) / FetchContent, or find_package(cbor) after install,
#               then  target_link_libraries(app PRIVATE cbor::cbor)  and  #include "cbor.hpp".
cmake_minimum_required(VERSION 3.21)

project(cbor
    VERSION 1.1.0
    DESCRIPTION "C++17 single-header CBOR codec with RFC 8746 typed arrays"
    LANGUAGES CXX)

include(GNUInstallDirs)

option(CBOR_BUILD_TESTS "Build the cbor test suite" ${PROJECT_IS_TOP_LEVEL})
option(CBOR_BUILD_EXAMPLES "Build the cbor examples (run as tests)" ${PROJECT_IS_TOP_LEVEL})
option(CBOR_INSTALL "Generate the cbor install/export rules" ${PROJECT_IS_TOP_LEVEL})

# --- library: header-only INTERFACE target --------------------------------------------
add_library(cbor INTERFACE)
add_library(cbor::cbor ALIAS cbor)
target_compile_features(cbor INTERFACE cxx_std_17)
# The header sits next to the MATLAB/Python twins; only cbor.hpp is installed.
target_include_directories(cbor INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)

# --- tests --------------------------------------------------------------------------------
if(CBOR_BUILD_TESTS)
    enable_testing()
    add_executable(cbor_test cbor_test.cpp)
    target_link_libraries(cbor_test PRIVATE cbor::cbor)
    set_target_properties(cbor_test PROPERTIES CXX_EXTENSIONS OFF)
    if(MSVC)
        target_compile_options(cbor_test PRIVATE /W4)
    else()
        target_compile_options(cbor_test PRIVATE -Wall -Wextra -pedantic)
    endif()

    add_test(NAME cbor.unit COMMAND cbor_test)

    # Self round trip: --write a logger stream, --read it back.
    add_test(NAME cbor.stream_write COMMAND cbor_test --write cpp.cbor)
    add_test(NAME cbor.stream_read COMMAND cbor_test --read cpp.cbor)
    set_tests_properties(cbor.stream_write PROPERTIES FIXTURES_SETUP cbor_stream)
    set_tests_properties(cbor.stream_read PROPERTIES FIXTURES_REQUIRED cbor_stream)

    # Interop against Python cbor2 — only if a Python 3 with cbor2 is found
    # (e.g. configure with -DPython3_EXECUTABLE=.venv/bin/python).
    find_package(Python3 COMPONENTS Interpreter QUIET)
    if(Python3_Interpreter_FOUND)
        execute_process(COMMAND ${Python3_EXECUTABLE} -c "import cbor2"
            RESULT_VARIABLE _cbor2_missing OUTPUT_QUIET ERROR_QUIET)
        if(_cbor2_missing EQUAL 0)
            set(_check ${CMAKE_CURRENT_SOURCE_DIR}/cbor_interop_check.py)
            add_test(NAME cbor.interop_cpp_to_py
                COMMAND ${Python3_EXECUTABLE} ${_check} read cpp.cbor)
            set_tests_properties(cbor.interop_cpp_to_py PROPERTIES FIXTURES_REQUIRED cbor_stream)
            add_test(NAME cbor.interop_py_write
                COMMAND ${Python3_EXECUTABLE} ${_check} write py.cbor)
            add_test(NAME cbor.interop_py_to_cpp COMMAND cbor_test --read py.cbor)
            set_tests_properties(cbor.interop_py_write PROPERTIES FIXTURES_SETUP cbor_py_stream)
            set_tests_properties(cbor.interop_py_to_cpp PROPERTIES FIXTURES_REQUIRED cbor_py_stream)
            message(STATUS "cbor: cbor2 interop tests enabled (${Python3_EXECUTABLE})")
        else()
            message(STATUS "cbor: cbor2 not importable by ${Python3_EXECUTABLE} — interop tests skipped")
        endif()
    endif()
endif()

# --- examples -----------------------------------------------------------------------------
if(CBOR_BUILD_EXAMPLES)
    add_subdirectory(examples/struct_roundtrip)
    if(CBOR_BUILD_TESTS)
        add_test(NAME cbor.example_struct_roundtrip COMMAND struct_roundtrip)
    endif()
endif()

# --- install / package config -------------------------------------------------------------
if(CBOR_INSTALL)
    include(CMakePackageConfigHelpers)

    install(TARGETS cbor EXPORT cborTargets)
    install(FILES cbor.hpp DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
    install(EXPORT cborTargets
        NAMESPACE cbor::
        DESTINATION ${CMAKE_INSTALL_DATADIR}/cmake/cbor)

    configure_package_config_file(cmake/cborConfig.cmake.in
        ${CMAKE_CURRENT_BINARY_DIR}/cborConfig.cmake
        INSTALL_DESTINATION ${CMAKE_INSTALL_DATADIR}/cmake/cbor)
    write_basic_package_version_file(${CMAKE_CURRENT_BINARY_DIR}/cborConfigVersion.cmake
        COMPATIBILITY SameMajorVersion
        ARCH_INDEPENDENT)
    install(FILES
        ${CMAKE_CURRENT_BINARY_DIR}/cborConfig.cmake
        ${CMAKE_CURRENT_BINARY_DIR}/cborConfigVersion.cmake
        DESTINATION ${CMAKE_INSTALL_DATADIR}/cmake/cbor)
endif()

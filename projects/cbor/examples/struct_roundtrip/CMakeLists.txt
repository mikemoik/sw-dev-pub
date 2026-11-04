# struct_roundtrip — serialize a C++ struct to CBOR and back with cbor::cbor.
# Standalone (cbor installed):  cmake -S . -B build -DCMAKE_PREFIX_PATH=<prefix> && cmake --build build
# Inside the cbor project it is built and run by CTest (CBOR_BUILD_EXAMPLES).
cmake_minimum_required(VERSION 3.21)
project(struct_roundtrip CXX)

if(NOT TARGET cbor::cbor)
    find_package(cbor 1.0 REQUIRED CONFIG)
endif()

add_executable(struct_roundtrip main.cpp)
target_link_libraries(struct_roundtrip PRIVATE cbor::cbor)   # also sets C++17

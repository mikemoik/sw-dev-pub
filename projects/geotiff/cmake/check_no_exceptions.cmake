# Fails if the header uses exception or RTTI keywords:  cmake -DHEADER=<file> -P check_no_exceptions.cmake
file(READ "${HEADER}" text)
foreach(word throw try catch dynamic_cast typeid)
    if(text MATCHES "(^|[^A-Za-z0-9_])${word}([^A-Za-z0-9_]|$)")
        message(FATAL_ERROR "${HEADER} contains '${word}'")
    endif()
endforeach()
message(STATUS "no exception / RTTI keywords in ${HEADER}")

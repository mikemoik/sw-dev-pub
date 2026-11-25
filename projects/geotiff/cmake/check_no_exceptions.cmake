# Fails if the library uses exception or RTTI keywords:
#   cmake -DHEADER=<geotiff.h> -DSOURCE=<geotiff.cpp> -P check_no_exceptions.cmake
file(READ "${HEADER}" text)
file(READ "${SOURCE}" source)
string(APPEND text "\n${source}")
foreach(word throw try catch dynamic_cast typeid)
    if(text MATCHES "(^|[^A-Za-z0-9_])${word}([^A-Za-z0-9_]|$)")
        message(FATAL_ERROR "${HEADER} or ${SOURCE} contains '${word}'")
    endif()
endforeach()
message(STATUS "no exception / RTTI keywords in ${HEADER} and ${SOURCE}")

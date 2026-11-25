# Fails if llm/knowledge.md disagrees with the code (header + source file, called "header" below):
#   cmake -DHEADER=<geotiff.h> -DSOURCE=<geotiff.cpp> -DTEST=<geotiff_test.cpp> -DKNOWLEDGE=<knowledge.md>
#         -P check_knowledge.cmake
#  - every tag constant of the code (kName = number) is a row of the tag table, with the same number
#  - every row of the tag table is a constant of the header
#  - every `name()` the file mentions is a function of the header or of the unit test
#  - the default tile size is the header's
file(READ "${HEADER}" header)
file(READ "${SOURCE}" source)
string(APPEND header "\n${source}")
file(READ "${TEST}" test)
file(READ "${KNOWLEDGE}" knowledge)
set(errors "")

# Tag constants: the enum that starts with kImageWidth.
string(REGEX MATCH "kImageWidth = [^}]*}" enum "${header}")
string(REGEX MATCHALL "k[A-Za-z]+ = [0-9]+" constants "${enum}")
string(REGEX MATCHALL "\\| `k[A-Za-z]+` \\| [0-9]+ \\|" rows "${knowledge}")
list(LENGTH constants constantCount)
list(LENGTH rows rowCount)
if(constantCount LESS 10)
    string(APPEND errors "  tag enum not found in the header\n")
endif()
foreach(constant IN LISTS constants)
    string(REGEX MATCH "^(k[A-Za-z]+) = ([0-9]+)$" _ "${constant}")
    string(FIND "${knowledge}" "| `${CMAKE_MATCH_1}` | ${CMAKE_MATCH_2} |" at)
    if(at EQUAL -1)
        string(APPEND errors "  header has ${constant}, the tag table has no such row\n")
    endif()
endforeach()
foreach(row IN LISTS rows)
    string(REGEX MATCH "`(k[A-Za-z]+)` \\| ([0-9]+)" _ "${row}")
    set(name "${CMAKE_MATCH_1}")
    set(number "${CMAKE_MATCH_2}")
    if(NOT enum MATCHES "${name} = ${number}[,\n ]")
        string(APPEND errors "  tag table has ${name} = ${number}, the header does not\n")
    endif()
endforeach()

# Functions mentioned as `name()`.
string(REGEX MATCHALL "`[A-Za-z_][A-Za-z0-9_]*\\(\\)`" mentions "${knowledge}")
list(REMOVE_DUPLICATES mentions)
list(LENGTH mentions mentionCount)
foreach(mention IN LISTS mentions)
    string(REGEX REPLACE "`(.*)\\(\\)`" "\\1" name "${mention}")
    if(NOT header MATCHES "[^A-Za-z0-9_]${name}\\(" AND NOT test MATCHES "[^A-Za-z0-9_]${name}\\(")
        string(APPEND errors "  ${name}() is in neither the header nor the unit test\n")
    endif()
endforeach()

# Default tile size.
string(REGEX MATCH "#define GEOTIFF_TILE_SIZE ([0-9]+)" _ "${header}")
string(FIND "${knowledge}" "`GEOTIFF_TILE_SIZE` (default ${CMAKE_MATCH_1})" at)
if(at EQUAL -1)
    string(APPEND errors "  default tile size ${CMAKE_MATCH_1} of the header is not the one in the file\n")
endif()

if(errors)
    message(FATAL_ERROR "${KNOWLEDGE} disagrees with the code:\n${errors}")
endif()
message(STATUS "knowledge.md agrees with the code: ${constantCount} tags, ${mentionCount} functions")

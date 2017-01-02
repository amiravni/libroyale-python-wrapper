cmake_minimum_required(VERSION 2.8)

### Check libroyale
if (NOT ROYALE_ROOT_DIR)
   message (FATAL_ERROR "Set \"ROYALE_ROOT_DIR\" to the path to libroyale directory. (If the path is relative, it must be relative to \"${CMAKE_CURRENT_SOURCE_DIR}\")")
endif ()

set (CMAKE_PREFIX_PATH "${ROYALE_ROOT_DIR}/share")
find_package (royale REQUIRED)
message("Found royale version ${royale_VERSION}, build ${royale_BUILD} at ${royale_INSTALL_PATH}")

if (APPLE)
   set (ROYALE_LIB "${royale_LIB_DIR}/lib${royale_LIBRARIES}CAPI.dylib")
elseif (UNIX)
   set (ROYALE_LIB "${royale_LIB_DIR}/lib${royale_LIBRARIES}CAPI.so")
else ()
   message (FATAL_ERROR "Not implemented for this platform")
endif()

### Check Python and NumPy
set (CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
find_package (Python REQUIRED)
find_package (NumPy REQUIRED)

### Check SWIG
find_package (SWIG REQUIRED)
include (${SWIG_USE_FILE})
include (GenerateExportHeader)

### Setup wrapper
include_directories (
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${PROJECT_BINARY_DIR}
    ${PYTHON_INCLUDE_PATH}
    ${PYTHON_NUMPY_INCLUDE_DIR}
)

set (CMAKE_SWIG_FLAGS "-Wall")

set (INTERFACE_FILE src/royale.i)

set (CMAKE_VERBOSE_MAKEFILE on)

message(${royale_LIBRARIES})
message(${royale_LIB_DIR})

set_source_files_properties(${INTERFACE_FILE} PROPERTIES CPLUSPLUS ON)
swig_add_module(royale python ${INTERFACE_FILE})
swig_link_libraries(royale ${PYTHON_LIBRARIES} ${ROYALE_LIB})

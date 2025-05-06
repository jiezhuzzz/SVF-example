cmake_minimum_required(VERSION 3.23)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

project(
    SVFStandalone
    VERSION 1.0
    DESCRIPTION "An example of how to use SVF as a library in a standalone tool"
    LANGUAGES C CXX)

include(GNUInstallDirs)

# Point this to whatever LLVM instance you want to use
set(CMAKE_C_COMPILER clang)
set(CMAKE_CXX_COMPILER clang++)
add_link_options("-fuse-ld=lld")

# Set the C and C++ standards
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_C_EXTENSIONS ON)
set(CMAKE_CXX_EXTENSIONS ON)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Create an executable for the example program to compile it into a LLVM bitcode file (.ll)
add_executable(example)
target_sources(example PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src/example.c)

# Enable LTO & create a position independent executable as an example
target_compile_options(example PRIVATE "-flto" "-fPIC")
target_link_options(example PRIVATE "-flto" "-fPIC")

# Enable compiler warnings
target_compile_options(example PRIVATE "-Wall" "-Wextra")
target_link_options(example PRIVATE "-Wall" "-Wextra")

# # If SVF was built without opaque pointers, don't build the example with it either
# if(NOT SVF_ENABLE_OPAQUE_POINTERS)
#     target_compile_options(example PRIVATE "-Xclang" "-no-opaque-pointers")
#     target_link_options(
#         example
#         PRIVATE
#         "-Xclang"
#         "-no-opaque-pointers"
#         "-Wl,-mllvm=-opaque-pointers=0"
#         "-Wl,-plugin-opt=no-opaque-pointers")
# endif()

# Add some nice debugging options for nicer output
target_compile_options(
    example
    PRIVATE "-g3"
            "-ggdb3"
            "-gdwarf"
            "-gpubnames"
            "-gcolumn-info"
            "-fdebug-macro"
            "-fstandalone-debug"
            "-fcolor-diagnostics"
            "-fno-discard-value-names"
            "-fno-eliminate-unused-debug-types")
target_link_options(
    example
    PRIVATE
    "-g3"
    "-ggdb3"
    "-gdwarf"
    "-gpubnames"
    "-gcolumn-info"
    "-fdebug-macro"
    "-fstandalone-debug"
    "-fcolor-diagnostics"
    "-fno-discard-value-names"
    "-fno-eliminate-unused-debug-types"
    "-Wl,--demangle"
    "-Wl,--emit-relocs"
    "-Wl,--discard-none"
    "-Wl,--no-gc-sections"
    "-Wl,--export-dynamic"
    "-Wl,--color-diagnostics=always")

# Add the -save-temps flag so the IR is generated during compilation (and not instead of)
set(EXAMPLE_PREPROC_FILE "${CMAKE_BINARY_DIR}/example.i")
set(EXAMPLE_BITCODE_FILE "${CMAKE_BINARY_DIR}/example.bc")
set(EXAMPLE_LLVM_IR_FILE "${CMAKE_BINARY_DIR}/example.ll")
target_compile_options(example PRIVATE "-save-temps")
target_link_options(example PRIVATE "-save-temps" "-Wl,--save-temps")

# "-save-temps" emits IR as binary bitcode (.bc) files; define a custom command (that always executed)
# to convert the binary .bc file into a human-readable (textual) LLVM IR (.ll) file using "llvm-dis"
add_custom_command(
    OUTPUT "${EXAMPLE_LLVM_IR_FILE}"
    COMMAND llvm-dis --color --show-annotations -o "${EXAMPLE_LLVM_IR_FILE}" "${EXAMPLE_BITCODE_FILE}"
    DEPENDS example)

# Add a custom target that depends on the custom command that generates .ll and add this target to the default set
add_custom_target(example_ir ALL DEPENDS "${EXAMPLE_LLVM_IR_FILE}")

install(TARGETS example RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES ${EXAMPLE_LLVM_IR_FILE} DESTINATION ${CMAKE_INSTALL_LIBDIR})

find_package(LLVM REQUIRED CONFIG)
message(STATUS "LLVM STATUS:
  Version       ${LLVM_VERSION}
  Includes      ${LLVM_INCLUDE_DIRS}
  Libraries     ${LLVM_LIBRARY_DIRS}
  Build type    ${LLVM_BUILD_TYPE}
  Dynamic lib   ${LLVM_LINK_LLVM_DYLIB}
  Enable excptions ${LLVM_ENABLE_EH}"
)
llvm_map_components_to_libnames(llvm_libs bitwriter core ipo irreader instcombine instrumentation target linker analysis scalaropts support )

# Find the SVF package (see notes in README.md)
find_package(SVF REQUIRED CONFIG HINTS "$ENV{SVF_DIR}/install" NO_DEFAULT_PATH)
message(STATUS "SVF STATUS:
    Found:                              ${SVF_FOUND}
    Version:                            ${SVF_VERSION}
    C++ standard:                       ${SVF_CXX_STANDARD}
    RTTI enabled:                       ${SVF_ENABLE_RTTI}
    Exceptions enabled:                 ${SVF_ENABLE_EXCEPTIONS}
    Install root directory:             ${SVF_INSTALL_ROOT}
    Install binary directory:           ${SVF_INSTALL_BIN_DIR}
    Install library directory:          ${SVF_INSTALL_LIB_DIR}
    Install include directory:          ${SVF_INSTALL_INCLUDE_DIR}
    Install 'extapi.bc' file path:      ${SVF_INSTALL_EXTAPI_FILE}"
)

# Define the tool itself
add_executable(SvfTool)
target_sources(SvfTool PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src/svf-tool.cpp)

# Define some compiler options for the tool
target_compile_options(
    SvfTool
    PRIVATE "-g3"
            "-flto"
            "-fPIC"
            "-Wall"
            "-Wextra")
target_link_options(
    SvfTool
    PRIVATE
    "-g3"
    "-flto"
    "-fPIC"
    "-Wall"
    "-Wextra")

# Link the SVF libraries; note that this also links the required LLVM libraries through transitive dependencies
target_link_libraries(SvfTool PRIVATE SvfCore SvfLLVM ${llvm_libs})
target_include_directories(SvfTool PRIVATE ${SVF_INSTALL_INCLUDE_DIR} ${LLVM_INCLUDE_DIRS})
target_link_directories(SvfTool PRIVATE ${SVF_INSTALL_LIB_DIR} ${LLVM_LIBRARY_DIRS})

#install(TARGETS SvfTool RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

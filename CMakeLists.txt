cmake_minimum_required(VERSION 3.19)

set(REMOTE_REPO_URL "https://github.com/vacuited/shell.git")

if(NOT DEFINED VERSION)
    # Try local git tag first, then remote tags, falling back to 1.0.0
    execute_process(
        COMMAND git -C "${CMAKE_CURRENT_SOURCE_DIR}" describe --tags --abbrev=0
        OUTPUT_VARIABLE LOCAL_TAG_RAW
        RESULT_VARIABLE LOCAL_TAG_RESULT
        ERROR_QUIET
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    if(LOCAL_TAG_RESULT EQUAL 0 AND NOT "${LOCAL_TAG_RAW}" STREQUAL "")
        set(VERSION "${LOCAL_TAG_RAW}")
    else()
        execute_process(
            COMMAND git ls-remote --tags --sort=-v:refname "${REMOTE_REPO_URL}"
            OUTPUT_VARIABLE REMOTE_TAGS_RAW
            RESULT_VARIABLE GIT_TAG_RESULT
            ERROR_QUIET
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )

        if(GIT_TAG_RESULT EQUAL 0 AND NOT "${REMOTE_TAGS_RAW}" STREQUAL "")
            string(REGEX MATCH "refs/tags/([^\n\^\t ]+)" _MATCH "${REMOTE_TAGS_RAW}")
            set(VERSION "${CMAKE_MATCH_1}")
        endif()
    endif()

    if(NOT DEFINED VERSION OR "${VERSION}" STREQUAL "")
        set(VERSION "1.0.0")
    endif()
endif()

if(NOT DEFINED GIT_REVISION)
    # Try local git HEAD first, then remote HEAD, falling back to unknown
    execute_process(
        COMMAND git -C "${CMAKE_CURRENT_SOURCE_DIR}" rev-parse HEAD
        OUTPUT_VARIABLE LOCAL_HEAD_RAW
        RESULT_VARIABLE LOCAL_REV_RESULT
        ERROR_QUIET
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    if(LOCAL_REV_RESULT EQUAL 0 AND "${LOCAL_HEAD_RAW}" MATCHES "^[0-9a-fA-F]+$")
        set(GIT_REVISION "${LOCAL_HEAD_RAW}")
    else()
        execute_process(
            COMMAND git ls-remote "${REMOTE_REPO_URL}" HEAD
            OUTPUT_VARIABLE REMOTE_HEAD_RAW
            RESULT_VARIABLE GIT_REV_RESULT
            ERROR_QUIET
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )

        if(GIT_REV_RESULT EQUAL 0 AND NOT "${REMOTE_HEAD_RAW}" STREQUAL "")
            string(REGEX MATCH "^([0-9a-fA-F]+)" GIT_REVISION "${REMOTE_HEAD_RAW}")
        endif()
    endif()

    if(NOT DEFINED GIT_REVISION OR "${GIT_REVISION}" STREQUAL "")
        set(GIT_REVISION "unknown")
    endif()
endif()

string(REGEX REPLACE "^v" "" VERSION "${VERSION}")
if(NOT "${VERSION}" MATCHES "^[0-9]+\\.[0-9]+(\\.[0-9]+)?(\\.[0-9]+)?$")
    set(VERSION "1.0.0")
endif()

project(caelestia-shell VERSION ${VERSION} LANGUAGES CXX)

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX "/" CACHE PATH "Installation prefix" FORCE)
endif()

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")

set(DISTRIBUTOR "Unset" CACHE STRING "Distributor")
set(ENABLE_MODULES "extras;plugin;shell" CACHE STRING "Modules to build/install")
set(INSTALL_LIBDIR "${CMAKE_INSTALL_LIBDIR}/caelestia" CACHE STRING "Library install dir")
set(INSTALL_QMLDIR "${CMAKE_INSTALL_LIBDIR}/qt6/qml" CACHE STRING "QML install dir")
set(INSTALL_QSCONFDIR "${CMAKE_INSTALL_SYSCONFDIR}/xdg/quickshell/caelestia" CACHE STRING "Quickshell config install dir")

add_compile_definitions(
    QT_NO_CAST_FROM_ASCII
    QT_NO_CAST_TO_ASCII
    QT_NO_CAST_FROM_BYTEARRAY
)

add_compile_options(
    -Wall -Wextra -Wpedantic -Wshadow -Wconversion
    -Wold-style-cast -Wnull-dereference -Wdouble-promotion
    -Wformat=2 -Wfloat-equal -Woverloaded-virtual
    -Wsign-conversion -Wredundant-decls -Wswitch
    -Wunreachable-code
)

if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    add_compile_options(-Wunused-lambda-capture -Wno-nonportable-include-path)
endif()

if("extras" IN_LIST ENABLE_MODULES)
    add_subdirectory(extras)
endif()

if("plugin" IN_LIST ENABLE_MODULES)
    add_subdirectory(plugin)
endif()

if("shell" IN_LIST ENABLE_MODULES)
    foreach(dir assets components daemons modules services utils)
        install(
            DIRECTORY ${dir}
            DESTINATION "${INSTALL_QSCONFDIR}"
            PATTERN "__pycache__" EXCLUDE
            PATTERN "*.pyc" EXCLUDE
            PATTERN "*.orig" EXCLUDE
            PATTERN "*.bak" EXCLUDE
        )
    endforeach()

    install(PROGRAMS assets/wrap_term_launch.sh DESTINATION "${INSTALL_QSCONFDIR}/assets")

    file(READ shell.qml SHELL_QML)
    string(REPLACE "settings.watchFiles: true" "settings.watchFiles: false" SHELL_QML "${SHELL_QML}")
    file(WRITE "${CMAKE_BINARY_DIR}/qml/shell.qml" "${SHELL_QML}")
    install(FILES "${CMAKE_BINARY_DIR}/qml/shell.qml" DESTINATION "${INSTALL_QSCONFDIR}")

    install(FILES LICENSE DESTINATION "${INSTALL_QSCONFDIR}")
endif()

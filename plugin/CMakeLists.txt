option(ENABLE_QUICKSHARE "Build optional Caelestia.QuickShare QML module (requires Protobuf and OpenSSL)" ON)

find_package(Qt6 REQUIRED COMPONENTS ShaderTools Core Qml Gui Quick QuickControls2 Concurrent Sql Network DBus Multimedia)
if(ENABLE_QUICKSHARE)
    find_package(Protobuf REQUIRED)
    find_package(OpenSSL REQUIRED)
endif()
find_package(PkgConfig REQUIRED)
pkg_check_modules(Qalculate IMPORTED_TARGET libqalculate REQUIRED)
pkg_check_modules(Pipewire IMPORTED_TARGET libpipewire-0.3 REQUIRED)
pkg_check_modules(Aubio IMPORTED_TARGET aubio REQUIRED)
pkg_check_modules(Cava IMPORTED_TARGET libcava QUIET)
if(NOT Cava_FOUND)
    pkg_check_modules(Cava IMPORTED_TARGET cava REQUIRED)
endif()
include(cmake/sensorslib.cmake)

set(QT_QML_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml")
qt_standard_project_setup(REQUIRES 6.9)

include(cmake/pch.cmake)
include(cmake/qml-module.cmake)

# Header only helpers
add_library(caelestia-util INTERFACE)
target_include_directories(caelestia-util INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")

add_subdirectory(3rdparty/rgbcx)
add_subdirectory(src/Caelestia)

file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/.vacuited-plugin"
    "distributor=${DISTRIBUTOR}\nversion=${VERSION}\nrevision=${GIT_REVISION}\n"
)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/.vacuited-plugin" DESTINATION "${INSTALL_QMLDIR}/Caelestia")

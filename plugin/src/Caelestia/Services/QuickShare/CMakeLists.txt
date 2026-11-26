set(PROTO_SRCS)
set(PROTO_HDRS)
protobuf_generate_cpp(PROTO_SRCS PROTO_HDRS
    proto/device_to_device_messages.proto
    proto/offline_wire_formats.proto
    proto/securegcm.proto
    proto/securemessage.proto
    proto/ukey.proto
    proto/wire_format.proto
)

qml_module(caelestia-quickshare
    URI Caelestia.QuickShare
    SOURCES
        QuickShareDiscovery.cpp
        QuickShareDiscovery.hpp
        QuickShareCrypto.cpp
        QuickShareCrypto.hpp
        QuickShareConnection.cpp
        QuickShareConnection.hpp
        quickshare_service.cpp
        quickshare_service.hpp
        QuickShareBle.cpp
        QuickShareBle.hpp
        ${PROTO_SRCS}
    LIBRARIES
        Qt::DBus
        Qt::Network
        protobuf::libprotobuf
        OpenSSL::Crypto
        OpenSSL::SSL
)

target_include_directories(caelestia-quickshare PRIVATE ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_BINARY_DIR})

add_executable(leanp2p_ping
    ping.cpp
)
target_link_libraries(leanp2p_ping
    libp2p
    p2p_protocol_ping
)
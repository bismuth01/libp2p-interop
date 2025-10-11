add_executable(ping
    ping.cpp
)
target_link_libraries(ping PRIVATE p2p::libp2p)
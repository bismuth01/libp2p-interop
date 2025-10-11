# C++ QUIC Ping Client

The executable is `build/ping/ping`

### Starting the client

```bash
./build/ping/ping
```

### Running the client with a connection string

```bash
./build/ping/ping <your-connection-string>
```

## Notes
- The leanp2p library does not directly provide a logging for incoming and outgoing messages for ping protocol. However, if anything fails, it will raise an error.
- To show the client in action: ping interval = 1 second & response timeout = 5 seconds.
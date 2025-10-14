# GO QUIC Ping Client

Build the client with
```bash
go build
```

If you encounter any compiling issues, it might be due to architecture mismatch.
You can also try building with
```bash
CGO_ENABLED=0 go build
```

An executable of `ping` will be generated.

### Start client

Start the client with
```bash
./ping
```

You will get a connection string once it starts.

### Start client with a connection string

To connect to a client using a connection string, use `-d` parameter.
```bash
./ping -d <your-connection-string>
```

## Extra parameters

- `-p`: Specify port to use
- `-s`: Specify seed to use for Host ID generation

## Notes
- To show the client in action: ping interval = 1 second & response timeout = 5 seconds.
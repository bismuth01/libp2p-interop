# Python QUIC Ping Client

Make sure py-libp2p is setup in the current python environment.

### Start client

Start the client with
```python
python ping.py
```

You will get the connection strings once the client starts running.

### Start client with a connection string

To connect to a client with a connection string, use the `-d` or `--destination` parameter
```python
python ping.py -d <your connection string>
```

## Extra parameters

`-s` or `--seed`: Set a seed for random peer id generation
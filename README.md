# Libp2p Interop Examples

This repository contains examples of interop for all libp2p implementations.

## State of protocols

✅ -> Tested and works

❌ -> Testing fails

🛠️ -> Under development

🚧 -> Development hasn't started

### Ping

|   FROM\TO  | leanp2p | py-libp2p | zig-libp2p | go-libp2p | js-libp2p | rust-libp2p |
|:----------:|:-------:|:---------:|:----------:|:---------:|:---------:|:---------:|
| leanp2p    |    ✅    |     ✅     |      🚧     |     ✅     |     🚧     |     ✅     |
| py-libp2p  |    ✅    |     ✅     |      🚧     |     ✅     |     🚧     |     ✅     |
| zig-libp2p |    🛠️    |     🛠️     |      🛠️     |     🛠️     |     🚧     |     🛠️     |
| go-libp2p  |    ✅    |     ✅     |      🚧     |     ✅     |     🚧     |     ✅     |
| js-libp2p  |    🚧    |     🚧     |      🚧     |     🚧     |     🚧     |     🚧     |
| rust-libp2p  |    ✅    |     ✅     |      🚧     |     ✅     |     🚧     |     ✅     |

## Setting up guides

The guides of setting up each implementation is given in its directory's `README.md`.

## Targetted implementations

- [leanp2p](https://github.com/qdrvm/leanp2p)

- [py-libp2p](https://github.com/libp2p/py-libp2p)

- [rust-libp2p](https://github.com/libp2p/rust-libp2p)

- [zig-libp2p](https://github.com/MarcoPolo/zig-libp2p)

- [go-libp2p](https://github.com/libp2p/go-libp2p)

- [js-libp2p](https://github.com/libp2p/js-libp2p)
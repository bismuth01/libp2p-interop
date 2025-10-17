# 🌐 Libp2p Interop Examples

This repository demonstrates interoperability across multiple [libp2p](https://libp2p.io/) implementations — including **LeanP2P**, a lightweight libp2p variant developed under the [Ethereum Foundation’s Lean Consensus P2P initiative](https://github.com/qdrvm/leanp2p). This effort is led by Siddharth and maintainers and core contributors of Py-libp2p.

The goal is to ensure that all libp2p stacks can communicate seamlessly across programming languages and protocol layers such as **QUIC**, **multistream-select**, and **ping** — strengthening cross-network interoperability between Ethereum and the broader Web3 ecosystem.

---

## 🚀 Overview

Each directory in this repository contains setup and testing guides for a specific libp2p implementation.  
These examples validate message exchange, connection negotiation, and protocol compatibility between peers implemented in different languages.

---

## ✅ State of Protocols

Legend:  
- ✅ → Tested and works  
- ❌ → Testing fails  
- 🛠️ → Under development  
- 🚧 → Development hasn't started  

### Ping Protocol Interoperability

|   FROM\TO  | leanp2p | py-libp2p | zig-libp2p | go-libp2p | js-libp2p | rust-libp2p |
|:----------:|:-------:|:---------:|:----------:|:---------:|:---------:|:------------:|
| **leanp2p**    |    ✅    |     ✅     |      🚧     |     ✅     |     🚧     |     ✅     |
| **py-libp2p**  |    ✅    |     ✅     |      🚧     |     ✅     |     🚧     |     ✅     |
| **zig-libp2p** |    🛠️    |     🛠️     |      🛠️     |     🛠️     |     🚧     |     🛠️     |
| **go-libp2p**  |    ✅    |     ✅     |      🚧     |     ✅     |     🚧     |     ✅     |
| **js-libp2p**  |    🚧    |     🚧     |      🚧     |     🚧     |     🚧     |     🚧     |
| **rust-libp2p**|    ✅    |     ✅     |      🚧     |     ✅     |     🚧     |     ✅     |

---

## ⚙️ Setting Up

Each implementation includes a `README.md` in its directory with step-by-step setup and run instructions.  
Refer to those to configure your environment, install dependencies, and run interop tests.

Example:
```bash
cd py-libp2p
python examples/ping.py

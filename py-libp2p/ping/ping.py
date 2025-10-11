import argparse
import logging

from multiaddr import Multiaddr
import trio

from libp2p import (
    new_host,
)
from libp2p.custom_types import (
    TProtocol,
)
from libp2p.network.stream.net_stream import (
    INetStream,
)
from libp2p.peer.peerinfo import (
    info_from_p2p_addr,
)
from libp2p.crypto.secp256k1 import create_new_key_pair

# Configure minimal logging
logging.basicConfig(level=logging.WARNING)
logging.getLogger("multiaddr").setLevel(logging.WARNING)
logging.getLogger("libp2p").setLevel(logging.WARNING)

PING_PROTOCOL_ID = TProtocol("/ipfs/ping/1.0.0")
PING_LENGTH = 32
PING_INTERVAL = 1
RESP_TIMEOUT = 5


async def handle_ping(stream: INetStream) -> None:
    while True:
        try:
            payload = await stream.read(PING_LENGTH)
            peer_id = stream.muxed_conn.peer_id
            if payload is not None:
                print(f"received ping from {peer_id}")

                await stream.write(payload)
                print(f"responded with pong to {peer_id}")

        except Exception:
            await stream.reset()
            break


async def send_ping(stream: INetStream) -> None:
    while True:
        try:
            payload = b"\x01" * PING_LENGTH
            print(f"sending ping to {stream.muxed_conn.peer_id}")

            await stream.write(payload)

            with trio.fail_after(RESP_TIMEOUT):
                response = await stream.read(PING_LENGTH)

            if response == payload:
                print(f"received pong from {stream.muxed_conn.peer_id}")

            await trio.sleep(PING_INTERVAL)

        except Exception as e:
            print(f"error occurred : {e}")
            break


async def run(port: int, destination: str, seed: int | None = None) -> None:
    from libp2p.utils.address_validation import (
        find_free_port,
        get_available_interfaces,
        get_optimal_binding_address,
    )

    if port <= 0:
        port = find_free_port()

    tcp_addrs = get_available_interfaces(port)
    quic_addrs = []
    for addr in tcp_addrs:
        addr_str = str(addr).replace("/tcp/", "/udp/") + "/quic-v1"
        quic_addrs.append(Multiaddr(addr_str))

    if seed:
        import random

        random.seed(seed)
        secret_number = random.getrandbits(32 * 8)
        secret = secret_number.to_bytes(length=32, byteorder="big")
    else:
        import secrets

        secret = secrets.token_bytes(32)

    host = new_host(enable_quic=True, key_pair=create_new_key_pair(secret))

    async with host.run(listen_addrs=quic_addrs), trio.open_nursery() as nursery:
        # Start the peer-store cleanup task
        nursery.start_soon(host.get_peerstore().start_cleanup_task, 60)

        if not destination:
            host.set_stream_handler(PING_PROTOCOL_ID, handle_ping)

            # Get all available addresses with peer ID
            all_addrs = host.get_addrs()

            print("Listener ready\nConnection strings: -")
            for addr in all_addrs:
                print(f"{addr}")

            # Use optimal address for the client command
            optimal_tcp = get_optimal_binding_address(port)
            optimal_quic_str = str(optimal_tcp).replace("/tcp/", "/udp/") + "/quic-v1"
            peer_id = host.get_id().to_string()
            optimal_quic_with_peer = f"{optimal_quic_str}/p2p/{peer_id}"
            print("Waiting for incoming connection...")

        else:
            maddr = Multiaddr(destination)
            info = info_from_p2p_addr(maddr)
            await host.connect(info)
            stream = await host.new_stream(info.peer_id, [PING_PROTOCOL_ID])

            nursery.start_soon(send_ping, stream)

            return

        await trio.sleep_forever()


def main() -> None:
    description = """
    This program demonstrates a simple p2p ping application using libp2p.
    To use it, first run 'python ping.py -p <PORT>', where <PORT> is the port number.
    Then, run another instance with 'python ping.py -p <ANOTHER_PORT> -d <DESTINATION>',
    where <DESTINATION> is the multiaddress of the previous listener host.
    """

    example_maddr = (
        "/ip4/[HOST IP]/udp/40675/quic-v1/p2p/16Uiu2HAmFPCLrYapfSbRv7uVLxhp3qkb2oLz16hJLZwV9wotM8aU"
    )

    parser = argparse.ArgumentParser(description=description)
    parser.add_argument("-p", "--port", default=0, type=int, help="source port number")

    parser.add_argument(
        "-d",
        "--destination",
        type=str,
        help=f"destination multiaddr string, e.g. {example_maddr}",
    )
    parser.add_argument(
        "-s",
        "--seed",
        type=int,
        help="provide a seed to the random number generator"
    )
    args = parser.parse_args()

    try:
        trio.run(run, args.port, args.destination, args.seed)
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()

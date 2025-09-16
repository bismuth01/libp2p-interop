#include <libp2p/log/simple.hpp>
#include <libp2p/protocol/ping.hpp>
#include <libp2p/injector/host_injector.hpp>
#include <libp2p/coro/spawn.hpp>
#include <libp2p/common/sample_peer.hpp>
#include <libp2p/transport/quic/transport.hpp>

int main(int argc, char **argv) {
    libp2p::simpleLoggingSystem();
    auto log = libp2p::log::createLogger("Ping");

    auto connect_info = libp2p::SamplePeer::makeEd25519(0).connect_info;
    if (argc >= 2){
        auto address = libp2p::Multiaddress::create(argv[1]).value();
        auto peer_id = libp2p::PeerId::fromBase58(address.getPeerId().value()).value();
        connect_info = {peer_id, {address}};
    }
    auto sample_peer = libp2p::SamplePeer::makeEd25519(1);

    auto injector = libp2p::injector::makeHostInjector(
        libp2p::injector::useKeyPair(sample_peer.keypair),
        libp2p::injector::useTransportAdaptors<libp2p::transport::QuicTransport()
    );
    auto io_context = injector.create<std::shared_ptr<boost::asio::io_context>>();
    auto host = injector.create<std::shared_ptr<libp2p::host::BasicHost>>();
    auto ping = injector.create<std::shared_ptr<libp2p::protocol::Ping>>();
    host->start();
    ping->start();

    // Set up a signal handler to gracefully stop the server on SIGINT or SIGTERM
    boost::asio::signal_set signals(*io_context, SIGINT, SIGTERM);
    signals.async_wait(
        [&](const boost::system::error_code &, int) { io_context->stop(); });

    // Run the I/O context event loop - this blocks until the server is stopped
    io_context->run();
    log->info("Server stopped");

    return 0;

}
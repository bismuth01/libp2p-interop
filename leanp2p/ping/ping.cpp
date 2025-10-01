#include <libp2p/log/simple.hpp>
#include <libp2p/common/sample_peer.hpp>
#include <libp2p/protocol/ping.hpp>
#include <libp2p/transport/quic/transport.hpp>
#include <libp2p/injector/host_injector.hpp>
#include <libp2p/coro/spawn.hpp>
#include <libp2p/crypto/random_generator.hpp>

int main(int argc, char** argv){
    libp2p::simpleLoggingSystem();
    auto log = libp2p::log::createLogger("Ping");

    auto connect_info = libp2p::SamplePeer::makeEd25519(0).connect_info;
    if(argc >= 2){
        auto address = libp2p::Multiaddress::create(argv[1]).value();
        auto peer_id =
        libp2p::PeerId::fromBase58(address.getPeerId().value()).value();
    connect_info = {peer_id, {address}};
    }
    auto sample_peer = libp2p::SamplePeer::makeEd25519(1);

    auto injector = libp2p::injector::makeHostInjector(
        libp2p::injector::useKeyPair(sample_peer.keypair),
        libp2p::injector::useTransportAdaptors<libp2p::transport::QuicTransport>());

    auto io_context = injector.create<std::shared_ptr<boost::asio::io_context>>();
    auto host = injector.create<std::shared_ptr<libp2p::host::BasicHost>>();
    auto config = injector.create<std::shared_ptr<libp2p::protocol::PingConfig>>();
    auto random = injector.create<std::shared_ptr<libp2p::crypto::random::RandomGenerator>>();
    auto ping = injector.create<std::shared_ptr<libp2p::protocol::Ping>>();

    host->start();
    ping->start();

    libp2p::coroSpawn(*io_context, [&]() -> libp2p::Coro<void> {
        log->info("Connect to {}", connect_info.addresses.at(0));
        auto temp = (co_await host->connect(sample_peer.connect_info));

        log->info("Connected!!");
        io_context->stop();
    });

    log->info("Client started");
    io_context->run();
    log->info("Client stopped");

    return 0;
}
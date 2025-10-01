#include <libp2p/log/simple.hpp>
#include <libp2p/common/sample_peer.hpp>
#include <libp2p/protocol/ping.hpp>
#include <libp2p/transport/quic/transport.hpp>
#include <libp2p/injector/host_injector.hpp>
#include <libp2p/coro/spawn.hpp>
#include <libp2p/crypto/random_generator.hpp>
#include <random>

int main(int argc, char** argv) {
    libp2p::simpleLoggingSystem();
    auto log = libp2p::log::createLogger("PingClient");

    // Parse destination multiaddress and peer id
    libp2p::peer::PeerInfo connect_info = libp2p::SamplePeer::makeEd25519(0).connect_info;
    if (argc >= 2) {
        auto address_res = libp2p::Multiaddress::create(argv[1]);
        auto address = address_res.value();
        auto peer_id_res = address.getPeerId();
        auto peer_id = libp2p::PeerId::fromBase58(peer_id_res.value());
        connect_info = {peer_id.value(), {address}};
    }

    // Generate a random seed for the sample peer
    unsigned int random_seed = static_cast<unsigned int>(std::random_device{}());
    auto sample_peer = libp2p::SamplePeer::makeEd25519(random_seed);

    auto injector = libp2p::injector::makeHostInjector(
        libp2p::injector::useKeyPair(sample_peer.keypair),
        libp2p::injector::useTransportAdaptors<libp2p::transport::QuicTransport>()
    );
    auto io_context = injector.create<std::shared_ptr<boost::asio::io_context>>();
    auto host = injector.create<std::shared_ptr<libp2p::host::BasicHost>>();
    auto random = injector.create<std::shared_ptr<libp2p::crypto::random::CSPRNG>>();

    libp2p::protocol::PingConfig ping_config{};
    auto ping = std::make_shared<libp2p::protocol::Ping>(io_context, host, random, ping_config);
    host->start();
    ping->start();

    log->info("Connection string: {}", sample_peer.connect);

    if(argc >= 2){
        libp2p::coroSpawn(*io_context, [&]() -> libp2p::Coro<void> {
            log->info("Connecting to {}", connect_info.addresses.at(0));
            auto connect_res = co_await host->connect(connect_info);
            if (!connect_res.has_value()) {
                log->error("Failed to connect to peer");
            } else {
                log->info("Connected to peer, pinging will start automatically");
            }
        });
    }

    log->info("Ping client started");
    boost::asio::signal_set signals(*io_context, SIGINT, SIGTERM);
    signals.async_wait(
        [&](const boost::system::error_code &, int) { io_context->stop(); });
    io_context->run();
    log->info("Ping client stopped");
    return 0;
}
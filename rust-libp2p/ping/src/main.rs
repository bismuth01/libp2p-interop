use std::{error::Error, time::Duration};

use futures::prelude::*;
use libp2p::{ping, swarm::SwarmEvent, Multiaddr};
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let _ = tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .try_init();

    let ping_config = ping::Config::new()
        .with_interval(Duration::from_secs(1))  // Set PING_INTERVAL to 1 second
        .with_timeout(Duration::from_secs(5));  // Set RESP_TIMEOUT to 5 seconds

    let mut swarm = libp2p::SwarmBuilder::with_new_identity()
        .with_tokio()
        .with_quic()
        .with_behaviour(|_| ping::Behaviour::new(ping_config))?
        .with_swarm_config(|cfg| cfg.with_idle_connection_timeout(Duration::from_secs(u64::MAX)))
        .build();

    // Tell the swarm to listen on all interfaces and a random, OS-assigned
    // port.
    swarm.listen_on("/ip4/127.0.0.1/udp/0/quic-v1".parse()?)?;

    // Dial the peer identified by the multi-address given as the second
    // command-line argument, if any.
    if let Some(addr) = std::env::args().nth(1) {
        let remote: Multiaddr = addr.parse()?;
        swarm.dial(remote)?;
        println!("Dialed {addr}")
    }

    loop {
        match swarm.select_next_some().await {
            SwarmEvent::NewListenAddr { address, .. } => {
                let listen_address = address.with_p2p(*swarm.local_peer_id()).unwrap();
                println!("Listening on {listen_address}")
            },
            SwarmEvent::Behaviour(event) => println!("{event:?}"),
            _ => {}
        }
    }
}
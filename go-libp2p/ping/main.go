package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"log"
	"math/rand"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/libp2p/go-libp2p"
	"github.com/libp2p/go-libp2p/core/crypto"
	"github.com/libp2p/go-libp2p/core/host"
	"github.com/libp2p/go-libp2p/core/network"
	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/libp2p/go-libp2p/core/protocol"

	ma "github.com/multiformats/go-multiaddr"
)

const (
	PingProtocol = protocol.ID("/ipfs/ping/1.0.0")
	PingLength   = 32
	PingInterval = time.Second
	RespTimeout  = 5 * time.Second
)

// HandlePing handles incoming ping streams
func HandlePing(stream network.Stream) {
	defer stream.Close()

	buf := make([]byte, PingLength)
	for {
		_, err := stream.Read(buf)
		if err != nil {
			if err != io.EOF {
				log.Printf("Error reading from stream: %s", err)
				stream.Reset()
			}
			return
		}

		peerId := stream.Conn().RemotePeer()
		log.Printf("received ping from %s", peerId.String())

		_, err = stream.Write(buf)
		if err != nil {
			log.Printf("Error writing to stream: %s", err)
			stream.Reset()
			return
		}
		log.Printf("responded with pong to %s", peerId.String())
	}
}

// StartPingClient starts a ping client that continuously pings the target peer
func StartPingClient(ctx context.Context, h host.Host, target peer.AddrInfo) error {
	if err := h.Connect(ctx, target); err != nil {
		return fmt.Errorf("failed to connect to peer: %w", err)
	}

	stream, err := h.NewStream(ctx, target.ID, PingProtocol)
	if err != nil {
		return fmt.Errorf("failed to open stream: %w", err)
	}
	defer stream.Close()

	payload := make([]byte, PingLength)
	for i := range payload {
		payload[i] = 0x01
	}

	respBuf := make([]byte, PingLength)
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
			log.Printf("sending ping to %s", target.ID.String())

			_, err := stream.Write(payload)
			if err != nil {
				return fmt.Errorf("failed to write ping: %w", err)
			}

			// Set read deadline
			if err := stream.SetReadDeadline(time.Now().Add(RespTimeout)); err != nil {
				return fmt.Errorf("failed to set read deadline: %w", err)
			}

			_, err = stream.Read(respBuf)
			if err != nil {
				return fmt.Errorf("failed to read pong: %w", err)
			}

			// Clear read deadline
			if err := stream.SetReadDeadline(time.Time{}); err != nil {
				return fmt.Errorf("failed to clear read deadline: %w", err)
			}

			// Verify response matches sent payload
			if string(respBuf) == string(payload) {
				log.Printf("received pong from %s", target.ID.String())
			} else {
				log.Printf("received invalid pong from %s", target.ID.String())
			}

			time.Sleep(PingInterval)
		}
	}
}

// ParsePeerAddr parses a multiaddr string into peer.AddrInfo
func ParsePeerAddr(addr string) (peer.AddrInfo, error) {
	maddr, err := ma.NewMultiaddr(addr)
	if err != nil {
		return peer.AddrInfo{}, err
	}

	info, err := peer.AddrInfoFromP2pAddr(maddr)
	if err != nil {
		return peer.AddrInfo{}, err
	}

	return *info, nil
}

func main() {
	// Parse command line arguments
	port := flag.Int("p", 0, "port to listen on (optional, random port will be used if not specified)")
	dest := flag.String("d", "", "destination multiaddr string (e.g., /ip4/127.0.0.1/udp/1234/quic-v1/p2p/QmPeerID)")
	seed := flag.Int64("s", 0, "random seed for key generation (optional)")
	flag.Parse()

	// If port is 0, it will automatically assign a random free port
	listenPort := *port

	// Create a context that will be canceled on interrupt
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Set up interrupt handler
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigChan
		log.Println("Received interrupt signal, shutting down...")
		cancel()
	}()

	// Set up the host
	var keyOpt libp2p.Option
	if *seed != 0 {
		// Use the seed to generate a deterministic key
		r := rand.New(rand.NewSource(*seed))
		priv, _, err := crypto.GenerateKeyPairWithReader(crypto.RSA, 2048, r)
		if err != nil {
			log.Fatal(err)
		}
		keyOpt = libp2p.Identity(priv)
	}

	opts := []libp2p.Option{
		libp2p.ListenAddrStrings(fmt.Sprintf("/ip4/0.0.0.0/udp/%d/quic-v1", listenPort)),
	}
	if keyOpt != nil {
		opts = append(opts, keyOpt)
	}

	host, err := libp2p.New(opts...)
	if err != nil {
		log.Fatal(err)
	}
	defer host.Close()

	// Print our address info
	addrs := host.Addrs()
	if len(addrs) == 0 {
		log.Fatal("No external addresses found")
	}

	hostAddr := fmt.Sprintf("%s/p2p/%s", addrs[0], host.ID())
	log.Printf("Host ID: %s", host.ID())
	log.Printf("Connection string: %s", hostAddr)

	if *dest == "" {
		host.SetStreamHandler(PingProtocol, HandlePing)
		addr := addrs[0]
		log.Printf("Listening for ping requests on %s", addr)
		log.Printf("Run with '-d %s' on another terminal to start pinging", hostAddr)
		<-ctx.Done()
	} else {
		targetInfo, err := ParsePeerAddr(*dest)
		if err != nil {
			log.Fatalf("Invalid target address: %v", err)
		}

		log.Printf("Starting ping to %s", targetInfo.ID)
		if err := StartPingClient(ctx, host, targetInfo); err != nil && err != context.Canceled {
			log.Fatal(err)
		}
	}
}

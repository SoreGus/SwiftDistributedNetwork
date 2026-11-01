# SwiftDistributedNetwork

**Version: 0.1.0**

Swift Package for distributed actor communication between Apple devices using Swift Distributed Actors, Swift Concurrency, and Network.framework.

## Requirements

- Swift 6.4+
- iOS 27+
- macOS 27+

## Installation

Add SwiftDistributedNetwork to your project using Swift Package Manager.

In Xcode, select **File → Add Package Dependencies** and enter the repository URL.

To use a specific release, select **Exact Version** and enter `0.1.0`.

Alternatively, add the package to your `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/OWNER/SwiftDistributedNetwork.git",
        from: "0.1.0"
    )
]
```

Replace `OWNER` with the GitHub repository owner.

## Modules

- **Contracts:** Shared distributed actor system, actor registration and resolution, message serialization, invocation handling, and communication contracts.
- **Host:** Distributed actor hosting through `DistributedHost`, TCP server lifecycle, connection management, and Bonjour service advertisement.
- **Client:** Remote actor access through `DistributedClient`, automatic actor resolution, Bonjour service discovery, TCP connections, and reconnection.

## Architecture

- Swift Distributed Actors
- Swift Concurrency
- Network.framework (TCP/IP)
- Bonjour (local network discovery)
- Automatic remote actor identification and resolution
- Length-prefixed JSON message transport
- Actor-based concurrency and connection management

The package separates shared communication infrastructure from application-specific distributed actors and business logic.

## Usage

### Shared Distributed Actor

Define your distributed actor in a separate Swift Package shared by the Host and Client applications.

```swift
import Contracts
import Distributed

public distributed actor RemoteCounter {

    public typealias ActorSystem = NetworkActorSystem

    private var count = 0

    public distributed func increment(
        amount: Int
    ) -> Int {
        count += amount
        return count
    }

    public distributed func currentValue() -> Int {
        count
    }

    public distributed func reset() {
        count = 0
    }
}
```

### macOS — Host

Publish the distributed actor using `DistributedHost`.

```swift
import Contracts
import Host
import RemoteCounterAPI

let host = DistributedHost()

let counter = RemoteCounter(
    actorSystem: host.actorSystem
)

try await host.start(
    actor: counter,
    serviceName: "CounterService",
    serviceType: "_counter._tcp",
    port: 8080
)
```

To stop hosting:

```swift
await host.stop()
```

### iOS — Client

Connect to the advertised Bonjour service and resolve the remote actor automatically.

```swift
import Client
import RemoteCounterAPI

let client = DistributedClient()

let counter = try await client.connect(
    actor: RemoteCounter.self,
    serviceName: "CounterService",
    serviceType: "_counter._tcp"
)

let result = try await counter.increment(
    amount: 10
)

let current = try await counter.currentValue()

try await counter.reset()

await client.disconnect()
```

No manual actor identifier exchange or direct TCP connection management is required.

### Application Dependencies

| Application | Required libraries |
|---|---|
| Shared actor package | `SwiftDistributedNetworkContracts` |
| macOS Host | `SwiftDistributedNetworkHost` and shared actor package |
| iOS Client | `SwiftDistributedNetworkClient` and shared actor package |

The shared actor package contains application-specific distributed actor types and data models. SwiftDistributedNetwork remains independent of application business logic.

## Local Network Permissions

Applications using Bonjour discovery must declare the appropriate local network permissions.

For iOS, configure `Info.plist`:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Connect to services on the local network.</string>

<key>NSBonjourServices</key>
<array>
    <string>_counter._tcp</string>
</array>
```

Replace `_counter._tcp` with your application's Bonjour service type.

For sandboxed macOS Host applications, enable the appropriate incoming network connections entitlement.

## Security

Version `0.1.0` is intended for trusted local networks.

Transport encryption and client authentication are not included in this release. Do not expose the TCP server directly to untrusted networks or the public internet.

## Development

Build:

```bash
swift build
```

Run tests:

```bash
swift test
```

## Release

**0.1.0 — Initial Release**

- Shared distributed actor communication infrastructure.
- Simplified public APIs through `DistributedHost` and `DistributedClient`.
- Automatic distributed actor registration and remote resolution.
- TCP server and connection lifecycle management.
- Bonjour service advertisement and discovery.
- Remote distributed actor method invocation with parameters and return values.
- Concurrent request handling.
- Connection timeout, cancellation, disconnection, and reconnection.
- Unit and integration tests for Contracts, Host, and Client.
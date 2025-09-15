# TinyDI

A lightweight dependency injection container for Swift with support for singletons, transients, and property wrappers.

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/tikhop/TinyDI.git", from: "1.0.0")
]
```

## Usage

### Basic Registration and Resolution

```swift
import TinyDI

// Register a service
DIContainer.register(DatabaseService.self) {
    DatabaseService()
}

// Resolve the service
let db = DIContainer.resolve(DatabaseService.self)
```

### Service Lifetimes

#### Singleton
Instance created once and reused for all resolutions:

```swift
DIContainer.singleton(Logger.self) {
    ConsoleLogger()
}

let logger1 = DIContainer.resolve(Logger.self)
let logger2 = DIContainer.resolve(Logger.self)
// logger1 and logger2 are the same instance
```

#### Transient
New instance created for each resolution:

```swift
DIContainer.transient(APIClient.self) {
    APIClient()
}

let client1 = DIContainer.resolve(APIClient.self)
let client2 = DIContainer.resolve(APIClient.self)
// client1 and client2 are different instances
```

### Named Services

Register multiple implementations of the same type:

```swift
DIContainer.register(Database.self, name: "primary") {
    PostgreSQL()
}

DIContainer.register(Database.self, name: "cache") {
    Redis()
}

let primaryDB = DIContainer.resolve(Database.self, name: "primary")
let cacheDB = DIContainer.resolve(Database.self, name: "cache")
```

### Dependency Resolution

Services can depend on other services:

```swift
DIContainer.singleton(Logger.self) {
    ConsoleLogger()
}

DIContainer.singleton(UserService.self) { container in
    UserService(logger: container.resolve(Logger.self))
}
```

### Property Wrapper

Use `@Injected` for automatic dependency resolution:

```swift
class ViewController {
    @Injected var userService: UserService
    @Injected(name: "primary") var database: Database

    func loadUser() {
        let user = userService.getCurrentUser()
    }
}
```

### Injectable Protocol

Conform to `Injectable` for automatic registration:

```swift
class UserRepository: Injectable {
    typealias Dependencies = DIContainer

    let logger: Logger
    let database: Database

    required init(dependencies: DIContainer) {
        self.logger = dependencies.resolve(Logger.self)
        self.database = dependencies.resolve(Database.self)
    }
}

// Register with automatic dependency injection
DIContainer.default.register(UserRepository.self, lifetime: .singleton)
```

### Instance vs Static Methods

Both instance and static methods are available:

```swift
// Using static methods (operates on default container)
DIContainer.register(Service.self) { Service() }
let service = DIContainer.resolve(Service.self)

// Using instance methods
let container = DIContainer()
container.register(Service.self) { Service() }
let service = container.resolve(Service.self)
```

### Method Chaining

Registration methods support chaining:

```swift
DIContainer.default
    .singleton(Logger.self) { ConsoleLogger() }
    .singleton(Database.self) { PostgreSQL() }
    .transient(APIClient.self) { APIClient() }
```

### Thread Safety

TinyDI uses `NSRecursiveLock` internally, making it thread-safe for concurrent access from multiple threads.

## API Reference

### DIContainer

- `register(_:name:lifetime:factory:)` - Register a service with specified lifetime
- `singleton(_:name:factory:)` - Register a singleton service
- `transient(_:name:factory:)` - Register a transient service
- `resolve(_:name:)` - Resolve a registered service
- `clearAll()` - Remove all registrations

### ServiceLifetime

- `.singleton` - Single instance shared across all resolutions
- `.transient` - New instance for each resolution

### @Injected

Property wrapper for automatic dependency injection. Supports named services via `@Injected(name:)`.

## Requirements

- Swift 6.1+
- iOS 13.0+ / tvOS 13.0+

## License

MIT

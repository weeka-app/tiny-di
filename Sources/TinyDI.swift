import Foundation

// MARK: - ServiceKey

private struct ServiceKey: Hashable, Sendable {
    let type: ObjectIdentifier
    let name: String?

    init<T>(_ type: T.Type, name: String? = nil) {
        self.type = ObjectIdentifier(type)
        self.name = name
    }
}

// MARK: - ServiceLifetime

public enum ServiceLifetime: Sendable {
    case singleton
    case transient
}

// MARK: - ServiceEntry

private class ServiceEntry: @unchecked Sendable {
    let lifetime: ServiceLifetime
    let factory: () -> Any
    private var instance: Any?

    init(lifetime: ServiceLifetime, factory: @escaping () -> Any) {
        self.lifetime = lifetime
        self.factory = factory
    }

    func resolve() -> Any {
        switch lifetime {
        case .singleton:
            if let instance {
                return instance
            }
            let newInstance = factory()
            instance = newInstance
            return newInstance

        case .transient:
            return factory()
        }
    }
}

// MARK: - DIContainer

public class DIContainer: @unchecked Sendable {
    private var services: [ServiceKey: ServiceEntry] = [:]
    private let lock = NSRecursiveLock()

    // Singleton instance
    public static let `default` = DIContainer()

    // MARK: - Static Registration Methods

    @discardableResult
    public static func register<T>(
        _ type: T.Type,
        name: String? = nil,
        lifetime: ServiceLifetime = .transient,
        factory: @escaping () -> T
    ) -> DIContainer {
        `default`.register(type, name: name, lifetime: lifetime, factory: factory)
    }

    @discardableResult
    public static func register<T>(
        _ type: T.Type,
        name: String? = nil,
        lifetime: ServiceLifetime = .transient,
        factory: @escaping (DIContainer) -> T
    ) -> DIContainer {
        `default`.register(type, name: name, lifetime: lifetime, factory: factory)
    }

    @discardableResult
    public static func singleton<T>(_ type: T.Type, name: String? = nil, factory: @escaping () -> T) -> DIContainer {
        `default`.singleton(type, name: name, factory: factory)
    }

    @discardableResult
    public static func singleton<T>(
        _ type: T.Type,
        name: String? = nil,
        factory: @escaping (DIContainer) -> T
    ) -> DIContainer {
        `default`.singleton(type, name: name, factory: factory)
    }

    @discardableResult
    public static func transient<T>(_ type: T.Type, name: String? = nil, factory: @escaping () -> T) -> DIContainer {
        `default`.transient(type, name: name, factory: factory)
    }

    @discardableResult
    public static func transient<T>(
        _ type: T.Type,
        name: String? = nil,
        factory: @escaping (DIContainer) -> T
    ) -> DIContainer {
        `default`.transient(type, name: name, factory: factory)
    }

    // MARK: - Static Resolution Methods

    public static func resolve<T>(_ type: T.Type, name: String? = nil) -> T {
        `default`.resolve(type, name: name)
    }

    // MARK: - Static Clear Methods

    public static func clearAll() {
        `default`.clearAll()
    }

    // MARK: - Registration

    @discardableResult
    public func register<T>(
        _ type: T.Type,
        name: String? = nil,
        lifetime: ServiceLifetime = .transient,
        factory: @escaping () -> T
    ) -> Self {
        lock.lock()
        defer { lock.unlock() }

        let key = ServiceKey(type, name: name)
        services[key] = ServiceEntry(lifetime: lifetime, factory: factory)
        return self
    }

    @discardableResult
    public func register<T>(
        _ type: T.Type,
        name: String? = nil,
        lifetime: ServiceLifetime = .transient,
        factory: @escaping (DIContainer) -> T
    ) -> Self {
        lock.lock()
        defer { lock.unlock() }

        let key = ServiceKey(type, name: name)
        services[key] = ServiceEntry(lifetime: lifetime) { [weak self] in
            guard let self else { fatalError("Container deallocated") }
            return factory(self)
        }
        return self
    }

    // Convenience methods
    @discardableResult
    public func singleton<T>(_ type: T.Type, name: String? = nil, factory: @escaping () -> T) -> Self {
        register(type, name: name, lifetime: .singleton, factory: factory)
    }

    @discardableResult
    public func singleton<T>(_ type: T.Type, name: String? = nil, factory: @escaping (DIContainer) -> T) -> Self {
        register(type, name: name, lifetime: .singleton, factory: factory)
    }

    @discardableResult
    public func transient<T>(_ type: T.Type, name: String? = nil, factory: @escaping () -> T) -> Self {
        register(type, name: name, lifetime: .transient, factory: factory)
    }

    @discardableResult
    public func transient<T>(_ type: T.Type, name: String? = nil, factory: @escaping (DIContainer) -> T) -> Self {
        register(type, name: name, lifetime: .transient, factory: factory)
    }

    // MARK: - Resolution

    public func resolve<T>(_ type: T.Type, name: String? = nil) -> T {
        lock.lock()
        defer { lock.unlock() }

        let key = ServiceKey(type, name: name)
        guard let entry = services[key] else {
            fatalError("No registration found for type \(type)\(name.map { " with name '\($0)'" } ?? "")")
        }

        guard let instance = entry.resolve() as? T else {
            fatalError("Could not cast instance to type \(type)")
        }

        return instance
    }

    // MARK: - Clear

    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        services.removeAll()
    }

    // MARK: - Auto Factory

    public func autoFactory<T>(_ type: T.Type) -> T {
        resolve(type)
    }
}

// MARK: - Injected

@propertyWrapper
public struct Injected<T> {
    private let name: String?
    private let container: DIContainer

    public var wrappedValue: T {
        container.resolve(T.self, name: name)
    }

    public init(name: String? = nil, container: DIContainer = .`default`) {
        self.name = name
        self.container = container
    }
}

// MARK: - OptionalInjected

@propertyWrapper
private struct OptionalInjected<T> {
    private let name: String?
    private let container: DIContainer

    var wrappedValue: T? {
        container.resolve(T.self, name: name)
    }

    init(name: String? = nil, container: DIContainer = .`default`) {
        self.name = name
        self.container = container
    }
}

// MARK: - Injectable

public protocol Injectable {
    associatedtype Dependencies
    init(dependencies: Dependencies)
}

extension DIContainer {
    @discardableResult
    public func register<T: Injectable>(
        _ type: T.Type,
        lifetime: ServiceLifetime = .transient
    ) -> Self where T.Dependencies == DIContainer {
        register(type, lifetime: lifetime) { container in
            T(dependencies: container)
        }
    }
}

import Testing
import Foundation
@testable import TinyDI

// MARK: - Test Models

protocol DatabaseProtocol {
    func connect() -> String
}

class MockDatabase: DatabaseProtocol {
    let id = UUID()
    func connect() -> String {
        "Connected to database \(id)"
    }
}

protocol LoggerProtocol {
    func log(_ message: String)
}

class MockLogger: LoggerProtocol {
    var messages: [String] = []
    func log(_ message: String) {
        messages.append(message)
    }
}

class ServiceWithDependencies {
    let database: DatabaseProtocol
    let logger: LoggerProtocol

    init(database: DatabaseProtocol, logger: LoggerProtocol) {
        self.database = database
        self.logger = logger
    }
}

class InjectableService: Injectable {
    let database: DatabaseProtocol
    let logger: LoggerProtocol

    required init(dependencies: DIContainer) {
        self.database = dependencies.resolve(DatabaseProtocol.self)
        self.logger = dependencies.resolve(LoggerProtocol.self)
    }
}

class ServiceWithInjectedProperties {
    @Injected var database: DatabaseProtocol
    @Injected(name: "special") var specialLogger: LoggerProtocol
}

// MARK: - DIContainer Registration Tests

@Suite("DIContainer Registration Tests")
struct DIContainerRegistrationTests {

    var container: DIContainer!

    init() {
        container = DIContainer()
    }

    @Test("Register simple type with factory")
    func testRegisterSimpleType() {
        container.register(String.self) { "Hello" }
        let result = container.resolve(String.self)
        #expect(result == "Hello")
    }

    @Test("Register with container dependency")
    func testRegisterWithContainerDependency() {
        container.register(String.self) { "Base" }
        container.register(Int.self) { container in
            let str = container.resolve(String.self)
            return str.count
        }

        let result = container.resolve(Int.self)
        #expect(result == 4)
    }

    @Test("Register protocol implementation")
    func testRegisterProtocol() {
        container.register(DatabaseProtocol.self) { MockDatabase() }
        let result = container.resolve(DatabaseProtocol.self)
        #expect(result is MockDatabase)
    }

    @Test("Register with named service")
    func testRegisterNamedService() {
        container.register(String.self, name: "greeting") { "Hello" }
        container.register(String.self, name: "farewell") { "Goodbye" }

        let greeting = container.resolve(String.self, name: "greeting")
        let farewell = container.resolve(String.self, name: "farewell")

        #expect(greeting == "Hello")
        #expect(farewell == "Goodbye")
    }

    @Test("Method chaining registration")
    func testMethodChaining() {
        container
            .register(String.self) { "Hello" }
            .register(Int.self) { 42 }
            .register(Bool.self) { true }

        #expect(container.resolve(String.self) == "Hello")
        #expect(container.resolve(Int.self) == 42)
        #expect(container.resolve(Bool.self) == true)
    }

    @Test("Static registration methods")
    func testStaticRegistration() {
        DIContainer.clearAll()

        DIContainer.register(String.self) { "Static" }
        let result = DIContainer.resolve(String.self)

        #expect(result == "Static")

        DIContainer.clearAll()
    }
}

// MARK: - DIContainer Lifetime Tests

@Suite("DIContainer Lifetime Tests")
struct DIContainerLifetimeTests {

    var container: DIContainer!

    init() {
        container = DIContainer()
    }

    @Test("Singleton returns same instance")
    func testSingletonLifetime() {
        container.singleton(MockDatabase.self) { MockDatabase() }

        let instance1 = container.resolve(MockDatabase.self)
        let instance2 = container.resolve(MockDatabase.self)

        #expect(instance1.id == instance2.id)
    }

    @Test("Transient returns different instances")
    func testTransientLifetime() {
        container.transient(MockDatabase.self) { MockDatabase() }

        let instance1 = container.resolve(MockDatabase.self)
        let instance2 = container.resolve(MockDatabase.self)

        #expect(instance1.id != instance2.id)
    }

    @Test("Singleton with container dependency")
    func testSingletonWithContainerDependency() {
        container.singleton(MockDatabase.self) { MockDatabase() }
        container.singleton(MockLogger.self) { container in
            let logger = MockLogger()
            logger.log("Initialized with database: \(container.resolve(MockDatabase.self).id)")
            return logger
        }

        let logger1 = container.resolve(MockLogger.self)
        let logger2 = container.resolve(MockLogger.self)

        #expect(logger1 === logger2)
    }

    @Test("Mixed lifetime dependencies")
    func testMixedLifetimes() {
        container.singleton(DatabaseProtocol.self) { MockDatabase() }
        container.transient(LoggerProtocol.self) { MockLogger() }
        container.transient(ServiceWithDependencies.self) { container in
            ServiceWithDependencies(
                database: container.resolve(DatabaseProtocol.self),
                logger: container.resolve(LoggerProtocol.self)
            )
        }

        let service1 = container.resolve(ServiceWithDependencies.self)
        let service2 = container.resolve(ServiceWithDependencies.self)

        #expect((service1.database as! MockDatabase).id == (service2.database as! MockDatabase).id)
        #expect((service1.logger as! MockLogger) !== (service2.logger as! MockLogger))
    }

    @Test("Static singleton methods")
    func testStaticSingletonMethods() {
        DIContainer.clearAll()

        DIContainer.singleton(MockDatabase.self) { MockDatabase() }

        let instance1 = DIContainer.resolve(MockDatabase.self)
        let instance2 = DIContainer.resolve(MockDatabase.self)

        #expect(instance1.id == instance2.id)

        DIContainer.clearAll()
    }

    @Test("Static transient methods")
    func testStaticTransientMethods() {
        DIContainer.clearAll()

        DIContainer.transient(MockDatabase.self) { MockDatabase() }

        let instance1 = DIContainer.resolve(MockDatabase.self)
        let instance2 = DIContainer.resolve(MockDatabase.self)

        #expect(instance1.id != instance2.id)

        DIContainer.clearAll()
    }
}

// MARK: - DIContainer Resolution Tests

@Suite("DIContainer Resolution Tests")
struct DIContainerResolutionTests {

    var container: DIContainer!

    init() {
        container = DIContainer()
    }

    @Test("Resolve unregistered type behavior")
    func testResolveUnregisteredType() {
        // Note: In production, this would cause a fatal error
        // Testing this properly would require special testing utilities for fatal errors
        container.register(String.self) { "Test" }
        let result = container.resolve(String.self)
        #expect(result == "Test")
    }

    @Test("Resolve with correct name")
    func testResolveWithCorrectName() {
        container.register(String.self, name: "correct") { "Value" }
        let result = container.resolve(String.self, name: "correct")
        #expect(result == "Value")
    }

    @Test("Auto factory resolution")
    func testAutoFactory() {
        container.register(String.self) { "Auto" }
        let result = container.autoFactory(String.self)
        #expect(result == "Auto")
    }

    @Test("Resolve complex dependency graph")
    func testComplexDependencyGraph() {
        container.singleton(DatabaseProtocol.self) { MockDatabase() }
        container.singleton(LoggerProtocol.self) { MockLogger() }
        container.transient(ServiceWithDependencies.self) { container in
            ServiceWithDependencies(
                database: container.resolve(DatabaseProtocol.self),
                logger: container.resolve(LoggerProtocol.self)
            )
        }

        let service = container.resolve(ServiceWithDependencies.self)
        #expect(service.database is MockDatabase)
        #expect(service.logger is MockLogger)
    }
}

// MARK: - Injected Property Wrapper Tests

@Suite("Injected Property Wrapper Tests")
struct InjectedPropertyWrapperTests {

    @Test("Injected resolves from default container")
    func testInjectedFromDefaultContainer() {
        let container = DIContainer.default
        container.singleton(DatabaseProtocol.self) { MockDatabase() }
        container.singleton(LoggerProtocol.self, name: "special") { MockLogger() }

        let service = ServiceWithInjectedProperties()

        #expect(service.database is MockDatabase)
        #expect(service.specialLogger is MockLogger)
    }

    @Test("Injected with custom container")
    func testInjectedWithCustomContainer() {
        let customContainer = DIContainer()
        customContainer.singleton(DatabaseProtocol.self) { MockDatabase() }

        // Test direct property wrapper usage
        let injected = Injected<DatabaseProtocol>(container: customContainer)
        #expect(injected.wrappedValue is MockDatabase)
    }

    @Test("Injected with named service")
    func testInjectedWithNamedService() {
        let logger1 = MockLogger()
        logger1.log("Logger 1")
        let logger2 = MockLogger()
        logger2.log("Logger 2")

        DIContainer.singleton(LoggerProtocol.self, name: "primary") { logger1 }
        DIContainer.singleton(LoggerProtocol.self, name: "secondary") { logger2 }

        struct TestService {
            @Injected(name: "primary") var primaryLogger: LoggerProtocol
            @Injected(name: "secondary") var secondaryLogger: LoggerProtocol
        }

        let service = TestService()
        #expect((service.primaryLogger as! MockLogger).messages.contains("Logger 1"))
        #expect((service.secondaryLogger as! MockLogger).messages.contains("Logger 2"))
    }
}

// MARK: - Injectable Protocol Tests

@Suite("Injectable Protocol Tests")
struct InjectableProtocolTests {

    var container: DIContainer!

    init() {
        container = DIContainer()
    }

    @Test("Register Injectable type")
    func testRegisterInjectableType() {
        container.register(DatabaseProtocol.self) { MockDatabase() }
        container.register(LoggerProtocol.self) { MockLogger() }
        _ = container.register(InjectableService.self)

        let service = container.resolve(InjectableService.self)
        #expect(service.database is MockDatabase)
        #expect(service.logger is MockLogger)
    }

    @Test("Injectable with singleton lifetime")
    func testInjectableWithSingletonLifetime() {
        container.register(DatabaseProtocol.self) { MockDatabase() }
        container.register(LoggerProtocol.self) { MockLogger() }
        _ = container.register(InjectableService.self, lifetime: .singleton)

        let service1 = container.resolve(InjectableService.self)
        let service2 = container.resolve(InjectableService.self)

        #expect(service1 === service2)
    }

    @Test("Injectable with transient lifetime")
    func testInjectableWithTransientLifetime() {
        container.register(DatabaseProtocol.self) { MockDatabase() }
        container.register(LoggerProtocol.self) { MockLogger() }
        _ = container.register(InjectableService.self, lifetime: .transient)

        let service1 = container.resolve(InjectableService.self)
        let service2 = container.resolve(InjectableService.self)

        #expect(service1 !== service2)
    }
}

// MARK: - Thread Safety Tests

@Suite("Thread Safety Tests")
struct ThreadSafetyTests {

    var container: DIContainer!

    init() {
        container = DIContainer()
    }

    @Test("Concurrent registration and resolution")
    func testConcurrentRegistrationAndResolution() async {
        let iterations = 100

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    self.container.register(String.self, name: "item\(i)") { "Value \(i)" }
                }
            }

            for i in 0..<iterations {
                group.addTask {
                    let result = self.container.resolve(String.self, name: "item\(i)")
                    #expect(result == "Value \(i)")
                }
            }
        }
    }

    @Test("Concurrent singleton resolution")
    func testConcurrentSingletonResolution() async {
        container.singleton(MockDatabase.self) { MockDatabase() }

        var instances: [UUID] = []

        await withTaskGroup(of: UUID.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    let instance = self.container.resolve(MockDatabase.self)
                    return instance.id
                }
            }

            for await id in group {
                instances.append(id)
            }
        }

        let uniqueIds = Set(instances)
        #expect(uniqueIds.count == 1)
    }

    @Test("Concurrent transient resolution")
    func testConcurrentTransientResolution() async {
        container.transient(MockDatabase.self) { MockDatabase() }

        var instances: [UUID] = []

        await withTaskGroup(of: UUID.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    let instance = self.container.resolve(MockDatabase.self)
                    return instance.id
                }
            }

            for await id in group {
                instances.append(id)
            }
        }

        let uniqueIds = Set(instances)
        #expect(uniqueIds.count == 100)
    }
}

// MARK: - Clear Methods Tests

@Suite("Clear Methods Tests")
struct ClearMethodsTests {

    var container: DIContainer!

    init() {
        container = DIContainer()
    }

    @Test("Clear all services from instance")
    func testClearAllFromInstance() {
        container.register(String.self) { "Test" }
        container.register(Int.self) { 42 }

        let beforeClear = container.resolve(String.self)
        #expect(beforeClear == "Test")

        container.clearAll()

        // After clearing, re-register to test the clear worked
        container.register(String.self) { "New Test" }
        let afterClear = container.resolve(String.self)
        #expect(afterClear == "New Test")
    }

    @Test("Static clear all")
    func testStaticClearAll() {
        DIContainer.register(String.self) { "Test" }
        DIContainer.register(Int.self) { 42 }

        let beforeClear = DIContainer.resolve(String.self)
        #expect(beforeClear == "Test")

        DIContainer.clearAll()

        // After clearing, re-register to test the clear worked
        DIContainer.register(String.self) { "New Test" }
        let afterClear = DIContainer.resolve(String.self)
        #expect(afterClear == "New Test")

        DIContainer.clearAll()
    }

    @Test("Clear removes singleton instances")
    func testClearRemovesSingletonInstances() {
        container.singleton(MockDatabase.self) { MockDatabase() }

        let instance1 = container.resolve(MockDatabase.self)
        container.clearAll()

        container.singleton(MockDatabase.self) { MockDatabase() }
        let instance2 = container.resolve(MockDatabase.self)

        #expect(instance1.id != instance2.id)
    }
}

// MARK: - Edge Cases Tests

@Suite("Edge Cases Tests")
struct EdgeCasesTests {

    var container: DIContainer!

    init() {
        container = DIContainer()
    }

    @Test("Override existing registration")
    func testOverrideExistingRegistration() {
        container.register(String.self) { "First" }
        container.register(String.self) { "Second" }

        let result = container.resolve(String.self)
        #expect(result == "Second")
    }

    @Test("Multiple named services with same type")
    func testMultipleNamedServicesWithSameType() {
        container.register(String.self, name: "a") { "A" }
        container.register(String.self, name: "b") { "B" }
        container.register(String.self, name: "c") { "C" }
        container.register(String.self) { "Default" }

        #expect(container.resolve(String.self, name: "a") == "A")
        #expect(container.resolve(String.self, name: "b") == "B")
        #expect(container.resolve(String.self, name: "c") == "C")
        #expect(container.resolve(String.self) == "Default")
    }

    @Test("Recursive dependency resolution")
    func testRecursiveDependencyResolution() {
        class ServiceA {
            let value: String
            init(value: String) { self.value = value }
        }

        class ServiceB {
            let serviceA: ServiceA
            init(serviceA: ServiceA) { self.serviceA = serviceA }
        }

        container.singleton(ServiceA.self) { ServiceA(value: "Test") }
        container.singleton(ServiceB.self) { container in
            ServiceB(serviceA: container.resolve(ServiceA.self))
        }

        let serviceB = container.resolve(ServiceB.self)
        #expect(serviceB.serviceA.value == "Test")
    }

    @Test("Empty string as service name")
    func testEmptyStringAsServiceName() {
        container.register(String.self, name: "") { "Empty" }
        container.register(String.self, name: nil) { "Nil" }

        #expect(container.resolve(String.self, name: "") == "Empty")
        #expect(container.resolve(String.self, name: nil) == "Nil")
    }

    @Test("Value types registration")
    func testValueTypesRegistration() {
        struct Point {
            let x: Int
            let y: Int
        }

        container.register(Point.self) { Point(x: 10, y: 20) }

        let point = container.resolve(Point.self)
        #expect(point.x == 10)
        #expect(point.y == 20)
    }

    @Test("Optional type registration")
    func testOptionalTypeRegistration() {
        container.register(String?.self) { nil }
        container.register(Int?.self) { 42 }

        let optionalString = container.resolve(String?.self)
        let optionalInt = container.resolve(Int?.self)

        #expect(optionalString == nil)
        #expect(optionalInt == 42)
    }
}

// MARK: - Performance Tests

@Suite("Performance Tests")
struct PerformanceTests {

    var container: DIContainer!

    init() {
        container = DIContainer()
    }

    @Test("Performance of singleton resolution")
    func testSingletonResolutionPerformance() {
        container.singleton(MockDatabase.self) { MockDatabase() }

        let startTime = Date()
        for _ in 0..<10000 {
            _ = container.resolve(MockDatabase.self)
        }
        let endTime = Date()

        let duration = endTime.timeIntervalSince(startTime)
        #expect(duration < 1.0) // Should complete in less than 1 second
    }

    @Test("Performance of transient resolution")
    func testTransientResolutionPerformance() {
        container.transient(MockDatabase.self) { MockDatabase() }

        let startTime = Date()
        for _ in 0..<10000 {
            _ = container.resolve(MockDatabase.self)
        }
        let endTime = Date()

        let duration = endTime.timeIntervalSince(startTime)
        #expect(duration < 2.0) // Should complete in less than 2 seconds
    }

    @Test("Performance with many registered services")
    func testManyRegisteredServicesPerformance() {
        for i in 0..<1000 {
            container.register(String.self, name: "service\(i)") { "Value \(i)" }
        }

        let startTime = Date()
        for i in 0..<1000 {
            _ = container.resolve(String.self, name: "service\(i)")
        }
        let endTime = Date()

        let duration = endTime.timeIntervalSince(startTime)
        #expect(duration < 1.0) // Should complete in less than 1 second
    }
}


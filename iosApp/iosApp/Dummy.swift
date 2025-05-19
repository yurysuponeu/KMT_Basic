// MARK: - Benchmark Swift File (Approx 1000 Lines)
// Purpose: Test IDE syntax highlighting performance.
// Contains a mix of Swift language features.

import Foundation // Common import
import SwiftUI // Another common framework for UI related types

// MARK: - Global Constants and Variables

let globalAppTitle: String = "BenchmarkApp"
var globalCounter: Int = 0
let defaultTimeout: TimeInterval = 30.0
private let internalApiKey = "SECRET_API_KEY_SHOULD_NOT_BE_HERE" // Example of a private global
fileprivate var fileScopedCounter = 0

struct AppConfiguration {
    let baseURL: URL
    var featureFlags: [String: Bool]
    static let defaultFlags: [String: Bool] = ["newUI": true, "loggingEnabled": false]
}

var currentConfig = AppConfiguration(baseURL: URL(string: "https://example.com/api")!, featureFlags: AppConfiguration.defaultFlags)

// MARK: - Protocols

protocol IdentifiableItem {
    var id: UUID { get }
}

protocol Nameable {
    var name: String { get set }
    func printName()
}

protocol Serializable {
    func toJson() -> String?
    static func fromJson(data: Data) -> Self?
}

protocol Calculatable {
    associatedtype ValueType: Numeric
    func calculate(input: ValueType) -> ValueType
}

// MARK: - Enums

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case timeout
    case serverError(statusCode: Int)
    case decodingError(error: Error)
    case unknown(message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The provided URL was invalid."
        case .timeout: return "The network request timed out."
        case .serverError(let code): return "Server returned error code \(code)."
        case .decodingError(let error): return "Failed to decode response: \(error.localizedDescription)"
        case .unknown(let message): return message ?? "An unknown network error occurred."
        }
    }
}

enum UserRole: String, CaseIterable, Codable {
    case guest = "GUEST"
    case member = "MEMBER"
    case moderator = "MOD"
    case administrator = "ADMIN"
}

enum ProcessingState<T, E: Error> {
    case idle
    case loading
    case success(T)
    case failure(E)
}

// MARK: - Structs

struct Coordinate: Hashable, Codable {
    var latitude: Double
    var longitude: Double

    func distance(to other: Coordinate) -> Double {
        // Haversine formula approximation - just for syntax
        let R = 6371e3 // metres
        let phi1 = latitude * .pi / 180
        let phi2 = other.latitude * .pi / 180
        let deltaPhi = (other.latitude - latitude) * .pi / 180
        let deltaLambda = (other.longitude - longitude) * .pi / 180

        let a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
            cos(phi1) * cos(phi2) *
            sin(deltaLambda / 2) * sin(deltaLambda / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return R * c // in metres
    }
}

struct UserProfile: IdentifiableItem, Nameable {
    let id: UUID
    var name: String
    var email: String?
    var role: UserRole
    var lastLogin: Date?
    var preferences: [String: String] = [:]

    // Nameable
    func printName() {
        print("User Name: \(name)")
    }

    // Example method with control flow
    func hasAdminPrivileges() -> Bool {
        switch role {
        case .administrator:
            return true
        case .moderator, .member, .guest:
            return false
        }
    }
}

// Another struct for variety
struct Product: Identifiable {
    let id = UUID() // Default implementation
    var sku: String
    var price: Decimal
    var quantity: Int
    var description: String? = nil // Optional property

    var totalPrice: Decimal {
        return price * Decimal(quantity)
    }

    mutating func updateQuantity(by delta: Int) {
        let newQuantity = quantity + delta
        if newQuantity >= 0 {
            quantity = newQuantity
        } else {
            print("Warning: Attempted to set negative quantity for SKU \(sku)")
            // Potentially throw an error here in real code
        }
    }
}


// MARK: - Classes

class NetworkManager {
    static let shared = NetworkManager() // Singleton pattern

    private let session: URLSession
    private var activeTasks: Set<URLSessionTask> = []
    private let taskQueue = DispatchQueue(label: "com.benchmark.networkmanager.queue")

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = defaultTimeout
        config.httpAdditionalHeaders = ["User-Agent": "BenchmarkApp/1.0"]
        self.session = URLSession(configuration: config)
        print("NetworkManager initialized.")
    }

    func fetchData(from urlString: String, completion: @escaping (Result<Data, NetworkError>) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(.failure(.invalidURL))
            return
        }

        let task = session.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            self.taskQueue.sync { // Ensure thread safety when modifying activeTasks
                // Note: In real async code, you wouldn't typically sync here,
                // but this adds complexity for the highlighter.
            }

            if let error = error {
                if (error as NSError).code == NSURLErrorTimedOut {
                    completion(.failure(.timeout))
                } else {
                    completion(.failure(.unknown(message: error.localizedDescription)))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.unknown(message: "Invalid response type")))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(.serverError(statusCode: httpResponse.statusCode)))
                return
            }

            guard let data = data else {
                completion(.failure(.unknown(message: "No data received")))
                return
            }

            completion(.success(data))
        }
        task.resume()
        globalCounter += 1 // Access global var
    }

    // Example async/await function
    @available(macOS 12.0, iOS 15.0, *)
    func fetchDataAsync(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }

        print("Starting async fetch for \(url.absoluteString)")
        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.unknown(message: "Invalid response type")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.serverError(statusCode: httpResponse.statusCode)
            }
            print("Async fetch completed successfully for \(url.absoluteString)")
            return data
        } catch {
            if (error as NSError).code == NSURLErrorTimedOut {
                throw NetworkError.timeout
            } else {
                print("Async fetch failed for \(url.absoluteString): \(error)")
                // Re-throw original error or a custom one
                throw NetworkError.unknown(message: error.localizedDescription)
            }
        }
    }


    deinit {
        session.invalidateAndCancel()
        print("NetworkManager deinitialized.")
    }
}

// Another class for variety
class DataProcessor: Calculatable {
    typealias ValueType = Double // Conforming to Calculatable

    private var cache: [String: Any] = [:]
    let processingID: String

    init(id: String = UUID().uuidString) {
        self.processingID = id
        // Load some initial data maybe
        self.cache["initialValue"] = 0.0
        self.cache["config"] = ["mode": "default", "retries": 3]
        self.cache["timestamp"] = Date()
    }

    func processData(input: Data) -> String? {
        // Simulate complex processing
        guard !input.isEmpty else { return nil }
        let stringRepresentation = String(decoding: input, as: UTF8.self)
        let reversed = String(stringRepresentation.reversed())
        let result = "Processed(\(processingID)): \(reversed.prefix(50))"
        cache["lastResult"] = result // Update cache
        fileScopedCounter += 1 // Access file private var
        return result
    }

    // Calculatable implementation
    func calculate(input: Double) -> Double {
        // Some arbitrary calculation
        let cachedValue = cache["initialValue"] as? Double ?? 1.0
        let calculation = (input * input + cachedValue) / 2.0
        print("Calculating: (\(input)^2 + \(cachedValue)) / 2 = \(calculation)")
        return calculation * Double(processingID.count % 5 + 1) // Use instance property
    }

    func clearCache() {
        cache.removeAll()
        print("Cache cleared for processor \(processingID)")
    }

    // Private helper
    private func logStatus(message: String) {
        #if DEBUG
        print("[DEBUG] \(processingID): \(message)")
        #else
        // In release builds, maybe log to a file or analytics service
        // print("[INFO] \(processingID): \(message)") // Or nothing
        #endif
    }
}

// MARK: - Extensions

extension String {
    var isEmail: Bool {
        // Basic regex for email format validation (for syntax highlighting)
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: self)
    }

    func trimmed() -> String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Converts a string to an integer, returning 0 if conversion fails.
    func toIntOrDefault() -> Int {
        return Int(self) ?? 0
    }
}

extension Int {
    var isEven: Bool {
        return self % 2 == 0
    }

    var digits: [Int] {
        return String(self).compactMap { Int(String($0)) }
    }
}

extension Date {
    func formatted(style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = style
        return formatter.string(from: self)
    }
}

// Extend a protocol
extension Serializable where Self: Encodable {
    func toJson() -> String? {
        let encoder = JSONEncoder()
        // Add specific encoding strategies if needed
        // encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

extension Serializable where Self: Decodable {
    static func fromJson(data: Data) -> Self? {
        let decoder = JSONDecoder()
        // Add specific decoding strategies if needed
        return try? decoder.decode(Self.self, from: data)
    }
}


// MARK: - Functions

func generateRandomString(length: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0..<length).map { _ in letters.randomElement()! })
}

func processItems<T>(_ items: [T], using processor: (T) -> Bool) -> [T] {
    var results: [T] = []
    for item in items {
        if processor(item) {
            results.append(item)
            // Nested control flow
            if results.count > 10 {
                print("Processed more than 10 items successfully.")
                // Early exit possibility
                // break
            }
        } else {
            print("Item \(item) did not pass processing.")
            // Using guard
            guard results.count < 100 else {
                print("Reached result limit, stopping.")
                return results // Exit function early
            }
            continue // Skip to next item
        }
    }
    // Ternary operator
    let message = results.isEmpty ? "No items passed processing." : "Processing complete. \(results.count) items passed."
    print(message)
    return results
}

// Function with closures and escaping parameters
func performBackgroundCalculation(input: Double, completion: @escaping (Result<Double, Error>) -> Void) {
    DispatchQueue.global(qos: .background).async {
        // Simulate work
        Thread.sleep(forTimeInterval: 0.05) // 50 ms sleep
        if input < 0 {
            completion(.failure(NetworkError.unknown(message: "Input cannot be negative")))
        } else {
            let result = sqrt(input) * 100.0
            // Call completion handler on main thread
            DispatchQueue.main.async {
                completion(.success(result))
            }
        }
        globalCounter += 1
    }
}


// MARK: - Generics

struct Stack<Element> {
    private var items: [Element] = []
    var isEmpty: Bool { return items.isEmpty }
    var count: Int { return items.count }

    mutating func push(_ item: Element) {
        items.append(item)
        print("Pushed \(item). Count: \(count)")
    }

    mutating func pop() -> Element? {
        guard !isEmpty else { return nil }
        let removed = items.removeLast()
        print("Popped \(removed). Count: \(count)")
        return removed
    }

    func peek() -> Element? {
        return items.last
    }
}

func findFirst<T: Equatable>(_ item: T, in collection: [T]) -> Int? {
    for (index, element) in collection.enumerated() {
        if element == item {
            return index
        }
    }
    return nil
}

// Generic function with constraints
func combine<T: Numeric>(a: T, b: T) -> T {
    return a + b
}

func processIfValid<C: Collection>(collection: C?) where C.Element: Comparable {
    guard let coll = collection, !coll.isEmpty else {
        print("Collection is nil or empty.")
        return
    }
    let sorted = coll.sorted()
    print("Sorted collection has \(sorted.count) elements. Min: \(sorted.first!), Max: \(sorted.last!)")
}

// MARK: - Property Wrappers

@propertyWrapper
struct Trimmed {
    private var value: String = ""

    var wrappedValue: String {
        get { value }
        set { value = newValue.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    init(wrappedValue: String) {
        self.wrappedValue = wrappedValue // Use setter logic during init
    }
}

@propertyWrapper
struct PositiveNumber<T: Numeric & Comparable> {
    private var number: T = 0

    var wrappedValue: T {
        get { number }
        set {
            if newValue >= 0 {
                number = newValue
            } else {
                print("Warning: Attempted to set negative value, keeping \(number)")
                // Or throw an error / clamp to 0
                // number = 0
            }
        }
    }

    init(wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }
}


struct UserSettings {
    @Trimmed var username: String
    @PositiveNumber var loginCount: Int = 0
    var lastSeen: Date?

    func display() {
        print("Username: '\(username)', Logins: \(loginCount)")
        if let seen = lastSeen {
            print("Last Seen: \(seen.formatted())")
        }
    }
}


// MARK: - SwiftUI View Example (for syntax diversity)

// Requires import SwiftUI at the top

struct BenchmarkView: View {
    @State private var textInput: String = "Initial Text"
    @State private var counterValue: Int = 0
    @State private var toggleState: Bool = true
    @State private var progress: Double = 0.3

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Benchmark UI Elements")
                .font(.largeTitle)
                .padding(.bottom)

            HStack {
                Text("Input:")
                TextField("Enter text here", text: $textInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            Text("Current Input: \(textInput)")
                .foregroundColor(textInput.isEmpty ? .red : .primary)

            Divider()

            HStack {
                Button("Increment Counter") {
                    counterValue += 1
                    globalCounter += 1 // Modify global counter
                }
                .padding(.trailing)

                Text("Counter: \(counterValue)")
                    .font(.headline)
            }

            Toggle("Enable Feature", isOn: $toggleState)
                .padding(.vertical)

            if toggleState {
                Text("Feature is ENABLED")
                    .foregroundColor(.green)
                    .transition(.opacity) // Add transition for syntax
            } else {
                Text("Feature is DISABLED")
                    .foregroundColor(.gray)
                    .transition(.slide) // Different transition
            }

            ProgressView("Loading Progress", value: progress, total: 1.0)
                .padding(.vertical)

            // Example of using timer
            Text("Timer Fired Count (Global): \(globalCounter)")
                .onReceive(timer) { _ in
                    // Simulate progress update
                    progress = (progress + 0.1).truncatingRemainder(dividingBy: 1.1)
                }

            Spacer() // Pushes content to the top

            // Using #if for conditional compilation syntax
            #if DEBUG
            Text("Debug Build Active")
                .font(.caption)
                .foregroundColor(.orange)
            #else
            Text("Release Build")
                .font(.caption)
                .foregroundColor(.blue)
            #endif

        }
        .padding() // Add padding to the VStack
        .navigationTitle("Benchmark") // Example navigation modifier
        .toolbar { // Example toolbar modifier
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Reset") {
                    resetState()
                }
            }
        }
    }

    private func resetState() {
        textInput = ""
        counterValue = 0
        toggleState = false
        progress = 0.0
        print("View state reset.")
    }
}

// MARK: - Actors (Concurrency)

@available(macOS 12.0, iOS 15.0, *)
    actor CounterActor {
    private var value = 0
    let actorId: String

    init(id: String = "DefaultActor") {
        self.actorId = id
        print("Actor \(actorId) initialized.")
    }

    func increment() -> Int {
        value += 1
        print("Actor \(actorId) incremented to \(value)")
        return value
    }

    func getValue() -> Int {
        print("Actor \(actorId) getting value \(value)")
        return value
    }

    // Async function within actor
    func incrementAfterDelay(seconds: Double) async -> Int {
        print("Actor \(actorId) will increment after \(seconds)s")
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        value += 1
        print("Actor \(actorId) delayed increment finished. New value: \(value)")
        return value
    }

    // Nonisolated function (can be called synchronously from outside)
    nonisolated func getActorID() -> String {
        // Cannot access isolated state 'value' here
        return actorId
    }
}


// MARK: - Sample Usage and Control Flow Examples

func runBenchmarkOperations() {
    print("\n--- Starting Benchmark Operations ---")

    // Struct usage
    var point1 = Coordinate(latitude: 50.0, longitude: 20.0)
    let point2 = Coordinate(latitude: 50.1, longitude: 20.1)
    let distance = point1.distance(to: point2)
    print("Distance between points: \(distance) meters")
    point1.latitude += 0.05 // Mutate struct property

    // Class usage
    let dataProcessor = DataProcessor(id: "Proc123")
    let inputData = "Some sample data to process".data(using: .utf8)!
    if let result = dataProcessor.processData(input: inputData) {
        print(result)
    }
    let calculation = dataProcessor.calculate(input: 10.5)
    print("Calculation result: \(calculation)")
    dataProcessor.clearCache()

    // Enum usage
    let status: ProcessingState<String, NetworkError> = .loading
    switch status {
    case .idle: print("State: Idle")
    case .loading: print("State: Loading")
    case .success(let data): print("State: Success - \(data)")
    case .failure(let error): print("State: Failure - \(error.localizedDescription)")
    }

    // Protocol and Extension usage
    let user = UserProfile(id: UUID(), name: "Alice Smith", email: "alice@example.com", role: .member)
    user.printName()
    if "test@domain.co".isEmail {
        print("It's a valid email format.")
    }
    let number = 12345
    print("Digits of \(number): \(number.digits)")

    // Function usage
    let random = generateRandomString(length: 12)
    print("Random string: \(random)")

    let numbers = [1, 5, 2, 8, 3, 9, 4, 6, 7, 10]
    let evenNumbers = processItems(numbers) { $0 % 2 == 0 }
    print("Even numbers found: \(evenNumbers)")

    // Closure usage
    performBackgroundCalculation(input: 25.0) { result in
        switch result {
        case .success(let value): print("Background calc success: \(value)")
        case .failure(let error): print("Background calc error: \(error)")
        }
    }

    // Generics usage
    var stringStack = Stack<String>()
    stringStack.push("Hello")
    stringStack.push("World")
    _ = stringStack.pop()
    if let top = stringStack.peek() {
        print("Top of stack: \(top)")
    }

    // Property Wrapper usage
    var settings = UserSettings(username: "  Bob ", loginCount: -5) // Login count will be corrected
    settings.loginCount = 10
    settings.lastSeen = Date()
    settings.username = "   Alice " // Will be trimmed
    settings.display()


    // Async/Await and Actor usage (requires appropriate context like Task or async func)
    if #available(macOS 12.0, iOS 15.0, *) {
        Task {
            print("\n--- Testing Async/Actor ---")
            let counterActor = CounterActor(id: "AsyncCounter")
            print("Actor ID (nonisolated): \(counterActor.getActorID())")

            // Concurrent increments
            async let val1 = counterActor.increment()
            async let val2 = counterActor.incrementAfterDelay(seconds: 0.1)
            async let val3 = counterActor.increment()

            let results = await [val1, val2, val3]
            print("Concurrent increment results (order may vary): \(results)")

            let finalValue = await counterActor.getValue()
            print("Final actor value: \(finalValue)")

            // Network async example
            do {
                let data = try await NetworkManager.shared.fetchDataAsync(from: "https://httpbin.org/get")
                print("Async fetch got \(data.count) bytes.")
                // Try decoding (might fail if httpbin output changes)
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Fetched JSON sample: \(jsonString.prefix(150))...")
                }

            } catch let error as NetworkError {
                print("Async fetch failed: \(error.localizedDescription)")
            } catch {
                print("An unexpected error occurred during async fetch: \(error)")
            }
            print("--- Async/Actor Test Complete ---")
        }
    } else {
        print("Async/Await/Actor features require newer OS version.")
    }


    // Final global counter check
    print("\nGlobal counter value: \(globalCounter)")
    print("File scoped counter value: \(fileScopedCounter)")
    print("--- Benchmark Operations Complete ---")

}

// MARK: - Entry Point (Conceptual)

// To make this runnable (e.g., in a command-line tool):
// @main struct BenchmarkApp {
//     static func main() {
//         runBenchmarkOperations()
//         // Keep running for async tasks if needed (e.g., using RunLoop)
//         if #available(macOS 12.0, iOS 15.0, *) {
//             print("Waiting for async tasks to potentially complete...")
//             // In a real app, the main run loop would handle this.
//             // For a simple tool, we might need to wait explicitly.
//             Thread.sleep(forTimeInterval: 2.0) // Simple wait
//             print("Exiting.")
//         }
//     }
// }

// Or just call the function if running in a Playground or other context
// runBenchmarkOperations()

// Add more lines if needed with simple constructs
func helperFunction1() { /* Empty function */ }
func helperFunction2(param: Int) -> Bool { return param > 0 }
let constant1 = 100
let constant2 = "Another string literal"
var variable1: Double? = nil
/*
  Multi-line comment
  spanning several lines
  to add more content and test comment highlighting.
  Line 1
  Line 2
  Line 3
*/

// Repeat some patterns to increase line count
struct DummyStruct1 { var a: Int; var b: String }
struct DummyStruct2 { var x: Double; var y: Double }
class DummyClass1 { func doThing() {} }
enum DummyEnum1 { case optionA, optionB, optionC }

let paddingVar1: Int = 1
let paddingVar2: String = "padding"
func paddingFunc1() { print("Pad 1") }
// line
func paddingFunc2() { print("Pad 2") }
// line Struct definition
struct PaddingStruct {
    var id: Int
    var value: String?
    func display() {
        print("PaddingStruct: \(id), \(value ?? "nil")")
    }
}
// line Class definition
class PaddingClass {
    private let creationDate = Date()
    func showDate() {
        print("PaddingClass created at: \(creationDate)")
    }
}
// line Final padding lines
var finalPadding1 = true
var finalPadding2 = false
let finalPadding3 = 1...10
// line
// line
// line
// line
// line
// line
// line
// line
// line
// line
// line
// line
// line

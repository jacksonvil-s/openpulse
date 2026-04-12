import Foundation
import RouterCore
import Combine

public class NetworkManager: ObservableObject {
    // UI-Bound Properties
    @Published public var interfaces: [NetworkInterface] = []
    @Published public var systemInfo: SystemInfo?
    @Published public var isAuthenticated = false
    @Published public var statusMessage: String = "Ready to connect"
    @Published public var countdown: Int = 10
    @Published public var rememberPassword = false
    @Published public var boardInfo: BoardInfo?
    @Published public var dhcpLeases: [DHCPLease] = []
    
    // Internal State
    public var sessionToken: String?
    private let routerURL = URL(string: "https://192.168.1.1/ubus")!
    private let session: URLSession
    private var refreshTimer: AnyCancellable?
    
    public init() {
        let configuration = URLSessionConfiguration.default
        // Use the SSLDelegate to bypass self-signed cert warnings
        self.session = URLSession(configuration: configuration, delegate: SSLDelegate(), delegateQueue: nil)
    }

    // MARK: - Logout
    public func logout() {
        stopAutoRefresh()
        self.sessionToken = nil
        self.isAuthenticated = false
        self.interfaces = []
        self.systemInfo = nil
        self.statusMessage = "Logged out"
    }
    
    // MARK: - Core Networking Helper
    private func sendUbusCommand(params: [Any]) async throws -> UbusResponse {
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": Int.random(in: 1...1000),
            "method": "call",
            "params": params
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: routerURL)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(UbusResponse.self, from: data)
    }

    // MARK: - Updated Login
    public func login(password: String) async {
        await MainActor.run { self.statusMessage = "Attempting login..." }
        
        let params: [Any] = ["00000000000000000000000000000000", "session", "login", ["username": "root", "password": password]]
        
        do {
            let decoded = try await sendUbusCommand(params: params)
            for item in decoded.result {
                if case let .session(sessionData) = item {
                    await MainActor.run {
                        self.sessionToken = sessionData.ubus_rpc_session
                        self.isAuthenticated = true
                        self.statusMessage = "Login Success!"
                        
                        // KEYCHAIN LOGIC:
                        if self.rememberPassword {
                            KeychainHelper.save(password)
                        } else {
                            KeychainHelper.delete()
                        }
                    }
                    await refreshAll()
                    startAutoRefresh()
                    return
                }
            }
        } catch {
            await MainActor.run { self.statusMessage = "Error: \(error.localizedDescription)" }
        }
    }

    // MARK: - Data Fetching
    public func refreshAll() async {
        guard isAuthenticated else { return }
        
        async let fetchInts: () = fetchInterfaces()
        async let fetchSys: () = fetchSystemStats()
        async let fetchBoard: () = fetchBoardInfo()
        async let fetchLeases: () = fetchDHCPLeases()
        
        _ = await [fetchInts, fetchSys, fetchBoard, fetchLeases]
    }

    public func fetchInterfaces() async {
        guard let token = sessionToken else { return }
        
        do {
            let decoded = try await sendUbusCommand(params: [token, "network.interface", "dump", [:]])
            await MainActor.run {
                for result in decoded.result {
                    if case let .data(list) = result {
                        self.interfaces = list.interface
                    }
                }
            }
        } catch {
            print("❌ Interface fetch failed: \(error)")
        }
    }

    public func fetchSystemStats() async {
        guard let token = sessionToken else { return }
        
        do {
            let decoded = try await sendUbusCommand(params: [token, "system", "info", [:]])
            await MainActor.run {
                for result in decoded.result {
                    if case let .system(info) = result {
                        self.systemInfo = info
                    }
                }
            }
        } catch {
            print("❌ System stats fetch failed: \(error)")
        }
    }

    // MARK: - New Data Fetchers
    public func fetchBoardInfo() async {
        guard let token = sessionToken else { return }
        do {
            let decoded = try await sendUbusCommand(params: [token, "system", "board", [:]])
            await MainActor.run {
                for result in decoded.result {
                    if case let .board(info) = result { self.boardInfo = info }
                }
            }
        } catch { print("Board fetch failed: \(error)") }
    }

    public func fetchDHCPLeases() async {
        guard let token = sessionToken else { return }
        do {
            // This relies on the standard LuCI RPC plugin
            let decoded = try await sendUbusCommand(params: [token, "luci-rpc", "getDHCPLeases", [:]])
            await MainActor.run {
                for result in decoded.result {
                    if case let .leases(leases) = result { self.dhcpLeases = leases }
                }
            }
        } catch {
            print("DHCP fetch failed (LuCI RPC might not be installed): \(error)")
        }
    }
    
    // MARK: - Updated Timer with Countdown
    public func startAutoRefresh() {
        stopAutoRefresh()
        countdown = 10
        refreshTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.countdown > 0 {
                    self.countdown -= 1
                } else {
                    self.countdown = 10
                    Task { await self.refreshAll() }
                }
            }
    }

    public func stopAutoRefresh() {
        refreshTimer?.cancel()
    }
    
    // MARK: - Keychain/Password
    public func checkSavedPassword() {
        if let saved = KeychainHelper.read() {
            self.rememberPassword = true
            // We don't auto-fill the 'password' String here because it's in the View,
            // but the View's .onAppear will handle the actual filling.
        }
    }
    
}

// MARK: - SSL Handling (Bypass Self-Signed Certs)
class SSLDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}


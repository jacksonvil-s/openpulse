import Foundation
import RouterCore
import Combine

public class NetworkManager: ObservableObject {
    @Published public var interfaces: [NetworkInterface] = []
    @Published public var isAuthenticated = false
    
    private var sessionToken: String?
    private let routerURL = URL(string: "https://192.168.1.1/ubus")!
    
    // Custom session to handle the self-signed certificate (SSL)
    private let session: URLSession
    
    public init() { // Must be public
            let configuration = URLSessionConfiguration.default
            self.session = URLSession(configuration: configuration, delegate: SSLDelegate(), delegateQueue: nil)
        }

    // MARK: - Step 1: Login
    public func login(password: String) async {
        let loginBody: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "call",
            "params": ["00000000000000000000000000000000", "session", "login", ["username": "root", "password": password]]
        ]
        
        do {
                    let data = try JSONSerialization.data(withJSONObject: loginBody)
                    var request = URLRequest(url: routerURL)
                    request.httpMethod = "POST"
                    request.httpBody = data
                    
                    let (responseData, _) = try await session.data(for: request)
                    let decoded = try JSONDecoder().decode(UbusResponse.self, from: responseData)
                    
                    // Look through the results for the session token
                    for item in decoded.result {
                        if case let .session(sessionInfo) = item {
                            await MainActor.run {
                                self.sessionToken = sessionInfo.ubus_rpc_session
                                self.isAuthenticated = true
                            }
                            print("Login Successful!")
                            await fetchInterfaces() // Get the data immediately
                            return
                        }
                    }
                    print("Login failed: No session token in response")
                } catch {
                    print("Login failed: \(error)")
                }
        }
    
    // MARK: - Step 2: Fetch Data
        public func fetchInterfaces() async {
            // We need that token we got from the login!
            guard let token = sessionToken else {
                print("No session token found. Please login first.")
                return
            }
            
            let body: [String: Any] = [
                "jsonrpc": "2.0",
                "id": 2,
                "method": "call",
                "params": [token, "network.interface", "dump", [:]]
            ]
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: body)
                var request = URLRequest(url: routerURL)
                request.httpMethod = "POST"
                request.httpBody = jsonData
                
                let (responseData, _) = try await session.data(for: request)
                let decoded = try JSONDecoder().decode(UbusResponse.self, from: responseData)
                
                // We must update @Published variables on the Main Thread (MainActor)
                await MainActor.run {
                    // Find the result that contains our data
                    for result in decoded.result {
                        if case let .data(interfaceList) = result {
                            self.interfaces = interfaceList.interface
                            print("Interfaces updated: \(self.interfaces.count) found.")
                        }
                    }
                }
            } catch {
                print("Fetch Interfaces failed: \(error)")
            }
        }
}

// This must be OUTSIDE the NetworkManager class braces
class SSLDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        // This tells the app: "If the router asks for a certificate trust, just say yes."
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

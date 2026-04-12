import Foundation

// The top-level ubus container
public struct UbusResponse: Codable {
    public let result: [UbusResult]
}

public enum UbusResult: Codable {
    case statusCode(Int)
    case data(InterfaceList)
    case session(SessionData) // Add this to handle login responses specifically

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // 1. Try to decode as an Int (the "0" success code)
        if let x = try? container.decode(Int.self) {
            self = .statusCode(x)
            return
        }
        
        // 2. Try to decode as SessionData (for login)
        if let x = try? container.decode(SessionData.self) {
            self = .session(x)
            return
        }
        
        // 3. Try to decode as InterfaceList (for network dump)
        if let x = try? container.decode(InterfaceList.self) {
            self = .data(x)
            return
        }
        
        throw DecodingError.typeMismatch(UbusResult.self, .init(codingPath: decoder.codingPath, debugDescription: "Unexpected ubus result type"))
    }
}

// Add this helper struct to your Models.swift as well
public struct SessionData: Codable {
    public let ubus_rpc_session: String
}

public struct InterfaceList: Codable {
    public let interface: [NetworkInterface]
}

public struct NetworkInterface: Codable, Identifiable {
    public var id: String { interface }
    public let interface: String
    public let up: Bool
    public let uptime: Int?
    public let proto: String
}

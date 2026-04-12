import Foundation

// The top-level ubus container
public struct UbusResponse: Codable {
    public let result: [UbusResult]
}

public enum UbusResult: Codable {
    case statusCode(Int)
    case data(InterfaceList)
    case session(SessionData)
    case system(SystemInfo)
    case board(BoardInfo)       // NEW
    case leases([DHCPLease])    // NEW

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let x = try? container.decode(Int.self) { self = .statusCode(x); return }
        if let x = try? container.decode(SessionData.self) { self = .session(x); return }
        if let x = try? container.decode(InterfaceList.self) { self = .data(x); return }
        if let x = try? container.decode(SystemInfo.self) { self = .system(x); return }
        if let x = try? container.decode(BoardInfo.self) { self = .board(x); return }
        if let x = try? container.decode([DHCPLease].self) { self = .leases(x); return }
        
        throw DecodingError.typeMismatch(UbusResult.self, .init(codingPath: decoder.codingPath, debugDescription: "Unexpected type"))
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

public struct SystemInfo: Codable {
    public let uptime: Int
    public let load: [Int] // [1min, 5min, 15min load]
    public let memory: MemoryInfo
}

public struct MemoryInfo: Codable {
    public let total: Int
    public let free: Int
    public let buffered: Int
}

public struct BoardInfo: Codable {
    public let model: String
    public let release: ReleaseInfo
}

public struct ReleaseInfo: Codable {
    public let description: String
    public let version: String
    public let revision: String
}

public struct DHCPLease: Codable, Identifiable {
    public var id: String { macaddr }
    public let ipaddr: String
    public let macaddr: String
    public let hostname: String
}

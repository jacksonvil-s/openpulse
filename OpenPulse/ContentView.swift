import SwiftUI
import RouterCore

struct ContentView: View {
    @StateObject var vm = NetworkManager()
    @State private var password = ""
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // --- SIDEBAR (Homepage is first) ---
            List {
                Section("Main") {
                    // 1. LOGIN IS NOW THE HOMEPAGE
                    NavigationLink(destination: LoginView(vm: vm, password: $password)) {
                        Label(vm.isAuthenticated ? "Connection Status" : "Login",
                              systemImage: vm.isAuthenticated ? "checkmark.shield" : "lock.shield")
                    }
                    
                    // 2. DASHBOARD IS SECONDARY
                    NavigationLink(destination: DashboardView(vm: vm)) {
                        Label("Dashboard", systemImage: "gauge")
                    }
                }
                
                if vm.isAuthenticated {
                    Section("System") {
                        Button(role: .destructive) {
                            vm.logout()
                        } label: {
                            Label("Logout", systemImage: "power")
                        }
                    }
                }
            }
            .navigationTitle("WarpDash")
            
        } detail: {
            // --- DETAIL VIEW DEFAULT ---
            // If authenticated, we can show Dashboard,
            // but the request was to make Login the homepage/entry.
            if !vm.isAuthenticated {
                LoginView(vm: vm, password: $password)
            } else {
                DashboardView(vm: vm)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            // Check keychain immediately on launch
            vm.checkSavedPassword()
        }
    }
}

// MARK: - Components
struct LoginView: View {
    @ObservedObject var vm: NetworkManager
    @Binding var password: String
    
    @State private var showLoginConfirmation = false
    
    var body: some View {
        VStack(spacing: 30) {
            if vm.isAuthenticated {
                // Connected State (Homepage when logged in)
                VStack(spacing: 15) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 100))
                        .foregroundColor(.green)
                    Text("Securely Connected")
                        .font(.largeTitle).bold()
                    Text("Router: 192.168.1.1")
                        .font(.subheadline).monospaced()
                    
                    Divider().frame(width: 200).padding()
                    
                    NavigationLink(destination: DashboardView(vm: vm)) {
                        Text("Go to Dashboard")
                            .frame(width: 200)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            } else {
                // Login State (Homepage when logged out)
                VStack(spacing: 20) {
                    Image(systemName: "wifi.router.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.accentColor)
                    
                    Text("WarpDash Login")
                        .font(.title).bold()
                    
                    VStack(alignment: .leading) {
                        SecureField("Root Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                        
                        Toggle("Remember Password", isOn: $vm.rememberPassword)
                            .font(.footnote)
                    }
                    .frame(maxWidth: 300)
                    
                    Button(action: { Task { await vm.login(password: password) } }) {
                        if vm.statusMessage.contains("Attempting") {
                            ProgressView().tint(.white)
                        } else {
                            Text("Connect")
                                .frame(maxWidth: 260)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Text(vm.statusMessage)
                        .font(.caption)
                        .foregroundColor(vm.statusMessage.contains("Error") ? .red : .secondary)
                }
            }
        }
        .padding()
        .onAppear {
            if let saved = KeychainHelper.read() {
                self.password = saved
            }
        }
    }
}

struct DashboardView: View {
    @ObservedObject var vm: NetworkManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                
                // 1. QUICK ACTIONS & STATUS CARD
                VStack(alignment: .leading, spacing: 12) {
                    Text("Router Status")
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "network")
                            .font(.system(size: 32))
                            .symbolRenderingMode(.multicolor)
                            .foregroundStyle(.green)
                        
                        VStack(alignment: .leading) {
                            Text("Connected")
                                .font(.title3.bold())
                            Text(vm.statusMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Button("Refresh") {
                                Task { await vm.refreshAll() }
                            }
                            .buttonStyle(.automatic)
                            
                            Text("Auto-refresh in \(vm.countdown)s")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .monospacedDigit()
                        }
                    }
                }
                .modifier(ControlCardModifier())
                
                // 2. SYSTEM RESOURCES CARD
                if let sys = vm.systemInfo {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("System Resources")
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)
                        
                        // Memory Bar
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Memory Usage")
                                Spacer()
                                Text("\((sys.memory.total - sys.memory.free) / 1024 / 1024) MB Used")
                                    .font(.caption).monospacedDigit()
                            }
                            
                            let totalMem = Double(sys.memory.total)
                            let usedMem = Double(sys.memory.total - sys.memory.free)
                            let usageRatio = usedMem / totalMem
                            
                            ProgressView(value: usedMem, total: totalMem)
                                .tint(usageRatio > 0.85 ? .red : (usageRatio > 0.6 ? .orange : .blue))
                                .scaleEffect(x: 1, y: 1.5, anchor: .center)
                        }
                        
                        Divider().padding(.vertical, 4)
                        
                        // Stats HStack
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Load Average")
                                    .font(.caption).foregroundColor(.secondary)
                                Text(String(format: "%.2f", Double(sys.load[0]) / 65535.0))
                                    .monospacedDigit()
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Uptime")
                                    .font(.caption).foregroundColor(.secondary)
                                Text("\(sys.uptime / 3600)h \((sys.uptime % 3600) / 60)m")
                                    .monospacedDigit()
                            }
                        }
                    }
                    .modifier(ControlCardModifier())
                }
                
                // 3. HARDWARE INFO CARD
                if let board = vm.boardInfo {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Hardware")
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Model")
                            Spacer()
                            Text(board.model).foregroundColor(.secondary)
                        }
                        Divider()
                        HStack {
                            Text("Firmware")
                            Spacer()
                            Text(board.release.version).foregroundColor(.secondary)
                        }
                    }
                    .modifier(ControlCardModifier())
                }
                
                // 4. NETWORK INTERFACES CARD
                if !vm.interfaces.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Interfaces")
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)
                        
                        ForEach(Array(vm.interfaces.enumerated()), id: \.element.id) { index, item in
                            InterfaceRow(item: item)
                            
                            // Add a divider between items, but not after the last one
                            if index < vm.interfaces.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .modifier(ControlCardModifier())
                }
                
                // 5. DHCP LEASES CARD
                if !vm.dhcpLeases.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Connected Devices")
                                .font(.subheadline.bold())
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(vm.dhcpLeases.count)")
                                .font(.caption).padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.2))
                                .cornerRadius(8)
                        }
                        
                        ForEach(Array(vm.dhcpLeases.enumerated()), id: \.element.id) { index, lease in
                            HStack {
                                Image(systemName: "laptopcomputer")
                                    .foregroundColor(.secondary)
                                VStack(alignment: .leading) {
                                    Text(lease.hostname == "*" ? "Unknown Device" : lease.hostname)
                                        .font(.subheadline).bold()
                                    Text(lease.macaddr.uppercased())
                                        .font(.caption2).foregroundColor(.secondary).monospaced()
                                }
                                Spacer()
                                Text(lease.ipaddr)
                                    .font(.caption).monospacedDigit()
                            }
                            
                            if index < vm.dhcpLeases.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .modifier(ControlCardModifier())
                }
                
            } // Main VStack
            .padding(20)
            .animation(.easeInOut, value: vm.countdown) // Smooth transitions
        } // ScrollView
        .navigationTitle("Dashboard")
        #if os(iOS)
        // Gives iOS that nice gray background so the cards pop out
        .background(Color(UIColor.systemGroupedBackground))
        .refreshable {
            await vm.refreshAll()
        }
        #endif
    }
}


struct InterfaceRow: View {
    let item: NetworkInterface
    
    var body: some View {
        HStack(spacing: 12) {
            // Status Indicator
            Circle()
                .fill(item.up ? Color.green : Color.red)
                .frame(width: 8, height: 8)
                .shadow(color: item.up ? .green.opacity(0.5) : .red.opacity(0.5), radius: 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.interface.uppercased())
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.bold)
                
                Text(item.proto)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Statistics
            if let uptime = item.uptime {
                VStack(alignment: .trailing) {
                    Text("\(uptime / 3600)h \((uptime % 3600) / 60)m")
                        .font(.system(.caption, design: .monospaced))
                    Text("UPTIME")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ControlCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            #if os(macOS)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            #else
            .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
            #endif
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
            )
    }
}

#Preview {
    ContentView()
}

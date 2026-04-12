import SwiftUI
import RouterCore

struct ContentView: View {
    @StateObject var vm = NetworkManager()
    @State private var password = ""
    
    var body: some View {
        NavigationStack {
            List {
                // Use 'vm' (no $) to check the boolean
                if !vm.isAuthenticated {
                    Section("Router Login") {
                        // Use $ on the local String 'password', not the VM
                        SecureField("Root Password", text: $password)
                        
                        Button("Connect") {
                            Task {
                                // Use 'vm' (no $) to call the function
                                await vm.login(password: password)
                            }
                        }
                    }
                } else {
                    Section("Network Interfaces") {
                        // Use 'vm.interfaces' (no $) to loop
                        ForEach(vm.interfaces) { item in
                            InterfaceRow(item: item)
                        }
                    }
                    
                    Section {
                        Button("Refresh Stats") {
                            Task {
                                // Use 'vm' (no $) and include ()
                                await vm.fetchInterfaces()
                            }
                        }
                    }
                }
            }
            .navigationTitle("WarpDash")
        }
    }
}

struct InterfaceRow: View {
    let item: NetworkInterface
    
    var body: some View {
        HStack {
            Circle()
                .fill(item.up ? Color.green : Color.red)
                .frame(width: 10, height: 10)
            Text(item.interface.uppercased())
                .font(.headline)
            Spacer()
            if let uptime = item.uptime {
                Text("\(uptime / 3600)h")
                    .font(.caption)
                    .monospaced()
            }
        }
    }
}

#Preview {
    ContentView()
}

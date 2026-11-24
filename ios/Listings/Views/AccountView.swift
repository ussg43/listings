import SwiftUI

struct AccountView: View {
    @Environment(AppModel.self) private var model
    @State private var showingAuth = false
    @State private var serverField = ""
    @State private var connectionStatus: String?
    @State private var isTesting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    if let user = model.currentUser {
                        LabeledContent("Signed in as", value: user.email)
                        LabeledContent("Member since", value: user.createdAt.formatted(date: .abbreviated, time: .omitted))
                        Button("Sign out", role: .destructive) {
                            model.signOut()
                            model.showToast("Signed out")
                        }
                    } else {
                        Text("Sign in to post and manage your listings.")
                            .foregroundStyle(.secondary)
                        Button("Sign in or create an account") { showingAuth = true }
                    }
                }

                Section {
                    TextField(AppModel.defaultServerURL, text: $serverField)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        Task { await saveAndTest() }
                    } label: {
                        if isTesting {
                            ProgressView()
                        } else {
                            Text("Save and test connection")
                        }
                    }
                    .disabled(isTesting)
                    if let connectionStatus {
                        Text(connectionStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Server")
                } footer: {
                    Text("The Simulator can use http://localhost:8080. A physical iPhone needs your Mac's address on the local network, such as http://192.168.1.20:8080.")
                }

                Section("Safety") {
                    Text("Meet in busy public places on campus, bring a friend if you can, and check the item before you pay.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Account")
            .onAppear { serverField = model.serverURLString }
            .sheet(isPresented: $showingAuth) { AuthView() }
        }
    }

    private func saveAndTest() async {
        isTesting = true
        defer { isTesting = false }
        do {
            try model.updateServerURL(serverField)
            serverField = model.serverURLString
            let healthy = await model.api.isHealthy()
            connectionStatus = healthy
                ? "Connected to the listings API."
                : "Saved, but the server didn't respond. Is the Go API running?"
            await model.refreshListings()
        } catch {
            connectionStatus = error.localizedDescription
        }
    }
}

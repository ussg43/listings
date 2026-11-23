import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            BrowseView()
                .tabItem { Label("Explore", systemImage: "house") }
            SavedView()
                .tabItem { Label("Saved", systemImage: "heart") }
            MyListingsView()
                .tabItem { Label("Sell", systemImage: "tag") }
            MeetupsView()
                .tabItem { Label("Meetups", systemImage: "calendar") }
            AccountView()
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
        .overlay(alignment: .top) { toast }
        .task {
            await model.refreshListings()
            model.startAutoRefresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.startAutoRefresh()
            } else {
                model.stopAutoRefresh()
            }
        }
    }

    @ViewBuilder private var toast: some View {
        if let message = model.toast {
            Text(message)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: Capsule())
                .shadow(radius: 4, y: 2)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

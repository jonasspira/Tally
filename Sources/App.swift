import SwiftUI

@main
struct TallyApp: App {
    init() {
        CurrencyRates.shared.refresh()   // pick up today's exchange rates
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 560, minHeight: 380)
        }
        .defaultSize(width: 840, height: 560)
    }
}

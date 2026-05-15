import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            // App icon if available
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .cornerRadius(20)
                .shadow(radius: 4)

            VStack(spacing: 4) {
                Text(Bundle.main.appName)
                    .font(.title2).bold()
                if let version = Bundle.main.appVersion, let build = Bundle.main.buildNumber {
                    Text("Version \(version) (\(build))")
                        .foregroundStyle(.secondary)
                }
            }

            Text("Keep your Mac awake on demand with quick timers and a lightweight menu bar controller.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Divider()

            VStack(spacing: 6) {
                Text("© \(Calendar.current.component(.year, from: Date())) Coffein")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Made By arj4ng")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(24)
        .frame(minWidth: 340, minHeight: 320)
    }
}

private extension Bundle {
    var appName: String { object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Coffein" }
    var appVersion: String? { object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String }
    var buildNumber: String? { object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String }
}

#Preview {
    AboutView()
}

import SwiftUI

struct AppAboutView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)
                .cornerRadius(20)
            Text("My Application")
                .font(.title)
                .fontWeight(.bold)
            Text("Version 1.0")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("© 2025 My Company")
                .font(.footnote)
                .foregroundColor(.secondary)
            Text("This is a simple about panel for the application.")
                .multilineTextAlignment(.center)
                .padding(.top)
        }
        .padding()
        .frame(minWidth: 300, minHeight: 300)
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}

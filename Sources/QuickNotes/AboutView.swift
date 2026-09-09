import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    let language: SupportedAppLanguage

    var body: some View {
        AppSheet(
            title: "About",
            language: language,
            minWidth: 400,
            minHeight: 320,
            closeAction: { dismiss() }
        ) {
            VStack(spacing: 12) {
                if let nsImage = NSImage(named: "AppIcon") {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .cornerRadius(20)
                        .shadow(color: AppTheme.brandBlue.opacity(0.16), radius: 10, x: 0, y: 5)
                } else {
                    Image(systemName: "note.text")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .frame(width: 120, height: 120)
                        .background(
                            AppTheme.titleGradient
                        )
                        .cornerRadius(20)
                        .shadow(color: AppTheme.brandBlue.opacity(0.16), radius: 10, x: 0, y: 5)
                }

                Text("Quick Notes")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(verbatim: AppLocalization.format(
                    "Version: %@ (%@)",
                    language: language,
                    arguments: getAppVersion(), getBuildVersion()
                ))
                    .font(.system(size: 12, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.secondary)

                Text("Webber Zhang")
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // Helper functions to get app info
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? AppLocalization.string("Unknown", language: language)
    }

    private func getBuildVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String
            ?? AppLocalization.string("Unknown", language: language)
    }

}

#Preview {
    AboutView(language: .englishUS)
}

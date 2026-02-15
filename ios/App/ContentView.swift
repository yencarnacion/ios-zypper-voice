import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var permissions: PermissionsViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Zypper Voice Keyboard")
                        .font(.largeTitle.bold())

                    Text("Use OpenAI voice transcription in English and Spanish from a custom keyboard extension.")
                        .font(.headline)

                    Text(permissions.statusMessage)
                        .font(.subheadline)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button("Grant Permissions") {
                        Task {
                            await permissions.requestAll()
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Divider()

                    Text("OpenAI Setup")
                        .font(.title2.bold())

                    Text("1. In Xcode, select target ZypperVoiceKeyboard > Info.")
                    Text("2. Add ZypperOpenAIAPIKey with your API key.")
                    Text("3. Leave ZypperOpenAILanguage empty for bilingual English/Spanish, or set en / es.")
                    Text("4. Leave ZypperOpenAIPrompt empty to use the built-in editor workflow prompt.")

                    Divider()

                    Text("Keyboard Setup")
                        .font(.title2.bold())

                    Text("1. Open Settings > General > Keyboard > Keyboards > Add New Keyboard.")
                    Text("2. Select Zypper Voice.")
                    Text("3. Open Zypper Voice keyboard in Settings and enable Allow Full Access.")
                    Text("4. In any app, tap globe key to switch keyboards and use the mic button.")
                }
                .padding()
            }
            .navigationTitle("Zypper Voice")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(PermissionsViewModel())
}

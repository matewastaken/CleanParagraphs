import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate{
    let clipboardManager = ClipboardManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            await checkVersion(currentVersion: "0.1")
        }
    }
    
    func checkVersion(currentVersion: String) async {
        guard let url = URL(string: "https://cleanparagraphs.vercel.app/version.json") else {return}
         
        do{
            let (data, _) = try await URLSession.shared.data(from: url)
            let remoteVersion = String(decoding: data, as: Unicode.UTF8.self)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if remoteVersion != currentVersion {
               let alert = NSAlert()
                alert.messageText = "Új verzió érhető el!"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Letöltés")
                alert.addButton(withTitle: "Később")
                
                if alert.runModal() == .alertFirstButtonReturn, let url = URL(string: "https://github.com/matewastaken/CleanParagraphs/releases/tag/latest") {
                    NSWorkspace.shared.open(url)
                }
            }else{
                print("Naprakész")
            }
        }catch{
            print("Hiba: \(error.localizedDescription)")
        }
    }
}

@main
struct CleanParagraphsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("appLanguage") private var selectedLanguage = AppLanguage.hungarian.rawValue

    var currentLocale: Locale {
        (AppLanguage(rawValue: selectedLanguage) ?? .hungarian).locale
    }
    
    var body: some Scene {
        MenuBarExtra("CleanParagraphs", systemImage: "clipboard.fill"){
            MenuView(clipboardManager: appDelegate.clipboardManager).environment(\.locale, currentLocale).id(selectedLanguage)
        }.menuBarExtraStyle(.window)
        
        Settings {
            SettingsView().environment(\.locale, currentLocale)
        }
    }
}


struct MenuView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @Environment(\.openSettings) private var openSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8){
            HStack{
                Text("CleanParagraphs").font(.caption).foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }, label: {
                    Image(systemName: "gear")
                })
            }
            Divider()
            if clipboardManager.history.isEmpty {
                Text("Nincsenek vágólap előzmények").font(.footnote).foregroundColor(.gray)
            }else{
                ForEach(clipboardManager.history){ element in
                    Button(action: {clipboardManager.copyToClipboard(element.cleanText)}){
                        HStack{
                            Text(element.cleanText).lineLimit(1).truncationMode(.tail)
                        }
                    }.buttonStyle(.plain)
                }
            }
            Divider()
            HStack{
                Button(action: {clipboardManager.emptyHistory()}, label: {Image(systemName: "xmark.bin.fill")})
                Spacer ()
                Button(action: {
                    if UserDefaults.standard.bool(forKey: "clearOnQuit") {
                        clipboardManager.emptyHistory()
                    }
                    NSApplication.shared.terminate(nil)},
                       label: {Image(systemName: "xmark.circle.fill")
                }
                )
            }
        }.padding(10).frame(width: 260)
    }
}

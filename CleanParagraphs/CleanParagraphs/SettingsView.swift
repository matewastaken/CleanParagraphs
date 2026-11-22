import SwiftUI
import ServiceManagement
import LocalAuthentication
public import Combine

struct AlwaysOnTopModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(WindowAccessor { window in
                window?.level = .floating
            })
    }
}

struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.callback(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
    func alwaysOnTop() -> some View {
        self.modifier(AlwaysOnTopModifier())
    }
}

final class LaunchManager: ObservableObject {
    @Published var isEnabled: Bool = false {
        didSet {
            updateLaunchState()
        }
    }
    
    private let service = SMAppService.mainApp
    
    init() {
        self.isEnabled = (service.status == .enabled)
    }
    
    private func updateLaunchState() {
        do {
            if isEnabled && service.status != .enabled {
                try service.register()
            } else if !isEnabled && service.status == .enabled {
                try service.unregister()
            }
        } catch {
            print("LaunchManager error: \(error.localizedDescription)")
        }
    }
}

struct AppSettings{
    
    static let languageKey = "cleanerLanguage"
    static let fixWrappedLinesKey = "fixWrappedLines"
    static let collapseMultipleSpacesKey = "collapseMultipleSpaces"
    static let fixPunctuationSpacingKey = "fixPunctuationSpacing"
    static let trimLinesKey = "trimLines"
    static let fixQuotesKey = "fixQuotes"
    static let invisibleCharsKey = "invisibleChars"
    
    static var currentCleanerOptions: TextCleaner.Options{
        let def = UserDefaults.standard
        
        let languageRaw = def.string(forKey: languageKey) ?? Language.hungarian.rawValue
        let language = Language(rawValue: languageRaw) ?? .hungarian
        let fixWrapped = def.object(forKey: fixWrappedLinesKey) as? Bool ?? true
        let collapseSpaces = def.object(forKey: collapseMultipleSpacesKey) as? Bool ?? true
        let fixPunct = def.object(forKey: fixPunctuationSpacingKey) as? Bool ?? true
        let trim = def.object(forKey: trimLinesKey) as? Bool ?? true
        let fixQuotes = def.object(forKey: fixQuotesKey) as? Bool ?? false
        let invisibleChars = def.object(forKey: invisibleCharsKey) as? Bool ?? false
        
        return TextCleaner.Options(language: language,fixWrappedLines: fixWrapped, collapseMultipleSpaces: collapseSpaces, fixPunctuationSpacing: fixPunct, trimLines: trim, fixQuotes: fixQuotes, removeInvisibleChars: invisibleChars)
    }
}

enum AppLanguage: String, CaseIterable, Identifiable{
    case hungarian = "hu"
    case english = "en"
    case german = "de"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .hungarian: return "Magyar"
        case .english: return "English"
        case .german: return "Deutsch"
        }
    }
    
    var locale: Locale {
        return Locale(identifier: rawValue)
    }
}

struct SettingsView: View{
    @StateObject private var launchMan = LaunchManager()
    
    private var verString = "0.1"
    @State private var authError: String?
    
    //altalanos beallitasok
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.hungarian.rawValue
    @AppStorage("historyLimit") private var historyLimit: Int = 10
    @AppStorage("clearOnQuit") private var clearOnQuit: Bool = false
    @AppStorage("passwordEnabled") private var passwordEnabled: Bool = false
    
    
    //formatalasi beallitasok
    @AppStorage(AppSettings.languageKey) private var cleanerLanguage = Language.hungarian.rawValue
    @AppStorage(AppSettings.fixWrappedLinesKey) private var fixWrappedLines = true
    @AppStorage(AppSettings.collapseMultipleSpacesKey) private var collapseMultipleSpaces = true
    @AppStorage(AppSettings.fixPunctuationSpacingKey) private var fixPunctuationSpacing = true
    @AppStorage(AppSettings.trimLinesKey) private var trimLines = true
    @AppStorage(AppSettings.fixQuotesKey) private var fixQuotes = false
    @AppStorage(AppSettings.invisibleCharsKey) private var invibisbleChars = false
    @State private var sampleInput: String = "Ez egy   teszt  szöveg.\n\n\nTöbb soremeléssel  és   szóközzel."

    var currentOptions: TextCleaner.Options {
        TextCleaner.Options(
            language: Language(rawValue: cleanerLanguage) ?? .hungarian,
            fixWrappedLines: fixWrappedLines,
            collapseMultipleSpaces: collapseMultipleSpaces,
            fixPunctuationSpacing: fixPunctuationSpacing,
            trimLines: trimLines,
            fixQuotes: fixQuotes,
            removeInvisibleChars: invibisbleChars
        )
    }
    
    var body: some View{
        TabView{
            Form{
                Section("Rendszer"){
                    Picker("App nyelve:", selection: $appLanguage){
                        ForEach(AppLanguage.allCases){lang in
                            Text(lang.displayName).tag(lang.rawValue)
                        }
                    }
                    Toggle("Elindítás bejelentkezéskor", isOn: $launchMan.isEnabled)
                }
                Section("Előzmények"){
                    Stepper("Előzmény limit: \(historyLimit)", value: $historyLimit, in: 5...35, step: 5)
                    Toggle("Előzmények törlése kilépéskor", isOn: $clearOnQuit)
                    Toggle(isOn: Binding(
                        get: {self.passwordEnabled},
                        set: {val in
                            authenticateUser{success in
                                if success {
                                    self.passwordEnabled = val
                                }
                            }
                        }
                    )){
                        VStack(alignment: .leading) {
                            Text("Jelszavak megjelenítése")
                                .bold()
                            Text("A funkció ki- és bekapcsolásához Touch ID vagy rendszerjelszó szükséges.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let authError = authError {
                        Text(authError)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }.formStyle(.grouped).tabItem{Label("Általános", systemImage: "gearshape")}
            
            Form{
                Section("Formázási szabályok"){
                    Picker("Karakterkészlet nyelve:", selection: $cleanerLanguage){
                        ForEach(Language.allCases){lang in
                            Text(lang.displayName).tag(lang.rawValue)
                        }
                    }
                    Toggle("Mondatközi soremelések összefűzése", isOn: $fixWrappedLines)
                    Toggle("Többszörös szóközök összevonása", isOn: $collapseMultipleSpaces)
                    Toggle("Írásjelek körüli szóközök igazítása", isOn: $fixPunctuationSpacing)
                    Toggle("Sorok széleinek megtisztítása", isOn: $trimLines)
                    Toggle("Tipográfiai idézőjelek cseréje", isOn: $fixQuotes)
                    Toggle("Láthatatlan karakterek törlése", isOn: $invibisbleChars)
                }
                Section("Élő teszter"){
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $sampleInput)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 70)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))
                        
                        Divider()
                        
                        Text("Eredmény:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(playground())
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.green)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(6)
                    }
                }
            }.formStyle(.grouped).tabItem{Label("Szabályok", systemImage: "wand.and.stars")}
            
            VStack(spacing: 16){
                Image(nsImage: NSApplication.shared.applicationIconImage).resizable().frame(width: 64, height: 64)
                                
                VStack(spacing: 4) {
                    Text("CleanParagraphs")
                        .font(.title2)
                        .bold()
                    Text("Verzió: \(verString)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text("Gyors és letisztult sorköz- és szövegformázó.")
                    .multilineTextAlignment(.center)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                Divider()
                    .padding(.vertical, 4)

                VStack(spacing: 10) {
                    Text("Tetszik az app? Támogasd a fejlesztést!")
                        .font(.caption)
                        .fontWeight(.medium)

                    Link(destination: URL(string: "https://ko-fi.com/matewastaken")!) {
                        HStack {
                            Image(systemName: "cup.and.saucer.fill")
                            Text("Buy me a Coffee on Ko-fi")
                        }
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .foregroundColor(.white)
                        .background(Color.orange)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .padding(24)
            .tabItem {
                Label("Névjegy", systemImage: "info.circle")
            }
            
        }.frame(width: 500, height: 420).alwaysOnTop().environment(\.locale, (AppLanguage(rawValue: appLanguage) ?? .hungarian).locale).onAppear{
            sampleInput = currentOptions.language.playgroundText
        }
        
    }
    
    func playground() -> String{
        //sampleInput = currentOptions.language.playgroundText
        return TextCleaner.clean(sampleInput, options: currentOptions)
    }
    
    private func authenticateUser(completion: @escaping (Bool) -> Void) {
            let context = LAContext()
            var error: NSError?

            let currentLangCode = appLanguage
            let bundle: Bundle
            if let path = Bundle.main.path(forResource: currentLangCode, ofType: "lproj"),
            let langBundle = Bundle(path: path) {
                bundle = langBundle
            } else {
                bundle = .main
            }
        
            if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                let reason = NSLocalizedString("A jelszó előzmények beállításainak módosításához igazold magad.", bundle: bundle, comment: "")

                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authenticationError in
                    DispatchQueue.main.async {
                        if success {
                            self.authError = nil
                            completion(true)
                        } else {
                            self.authError = NSLocalizedString("Sikertelen azonosítás.", bundle: bundle, comment: "")
                            completion(false)
                        }
                    }
                }
            } else {
                // Ha a rendszeren semmilyen védelem nincs beállítva
                DispatchQueue.main.async {
                    self.authError = NSLocalizedString("A rendszereden nincs beállítva jelszó vagy Touch ID.", bundle: bundle, comment:"")
                    completion(false)
                }
            }
        }
}

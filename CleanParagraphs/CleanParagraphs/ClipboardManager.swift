import Foundation
import AppKit
public import Combine

extension NSPasteboard{
    var isSensitiveOrPassword: Bool {
        if types?.contains(NSPasteboard.PasteboardType("org.nspasteboard.TransientType")) == true || types?.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")) == true {
            return true
        }
        
        let sensitiveTypes = [
            "com.agilebits.onepassword",
            "com.bitwarden.concealed",
            "de.keepassxc.keepassxc"
        ]
        
        if let types = types {
            for type in types {
                if sensitiveTypes.contains(type.rawValue) {
                    return true
                }
            }
        }
        
        return false
    }
}

struct ClipboardElement: Identifiable, Codable, Equatable {
    var id = UUID()
    let rawText: String
    let cleanText: String
    let timestamp: Date
}

class ClipboardManager: ObservableObject {
    @Published var history: [ClipboardElement] = [] {
        didSet {
            guard !isLoading else { return }
            saveHistory()
        }
    }

    private var historyLimit: Int {
        let limit = UserDefaults.standard.integer(forKey: "historyLimit")
        return limit > 0 ? limit : 10
    }
    
    private let pasteboard = NSPasteboard.general
    private var tempChangeCount: Int
    private var timer: Timer?
    private var isLoading = false
    
    private var fileURL: URL {
        let fileMan = FileManager.default
        let docDir = fileMan.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docDir.appendingPathComponent("history.json")
    }
    
    init() {
        self.tempChangeCount = pasteboard.changeCount
        loadHistory()
        startWorker()
    }
    
    func startWorker() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    private func checkClipboard() {
        guard pasteboard.changeCount != tempChangeCount else { return }
        tempChangeCount = pasteboard.changeCount
        
        guard let clipText = pasteboard.string(forType: .string),
              !clipText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let isPassword = pasteboard.isSensitiveOrPassword || isPasswordPattern(clipText)
        
        if isPassword && !UserDefaults.standard.bool(forKey: "passwordEnabled"){
            return
        }
        
        if history.first?.rawText == clipText { return }
        
        let newElement = ClipboardElement(rawText: clipText, cleanText: TextCleaner.clean(clipText), timestamp: Date())
        
        DispatchQueue.main.async {
            self.history.insert(newElement, at: 0)
            if self.history.count > self.historyLimit {
                self.history = Array(self.history.prefix(self.historyLimit))
            }
        }
    }
    
    func copyFormattedToClipboard() {
        guard let clipText = pasteboard.string(forType: .string),
              !clipText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let formattedText = TextCleaner.clean(clipText)
        copyToClipboard(formattedText)
    }
    
    func copyToClipboard(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        self.tempChangeCount = pasteboard.changeCount
    }
    
    func saveHistory() {
        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            print("Hiba a JSON mentésekor: \(error)")
        }
    }
    
    func loadHistory() {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decodedHistory = try JSONDecoder().decode([ClipboardElement].self, from: data)
            self.history = decodedHistory
        } catch {
            self.history = []
        }
    }
    
    func emptyHistory() {
        self.history.removeAll()
    }
    
    func isPasswordPattern(_ text: String) -> Bool{
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmed.count >= 6 && trimmed.count <= 64 else { return false }
        if trimmed.contains(" ") || trimmed.contains("\n") { return false }
        if trimmed.contains("@") && trimmed.contains(".") { return false }
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") { return false }
        let hasUppercase = trimmed.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = trimmed.range(of: "[a-z]", options: .regularExpression) != nil
        let hasDigit     = trimmed.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSpecial   = trimmed.range(of: "[!@#$%^&*()_+\\-=\\[\\]{};':\"\\\\|,.<>\\/?]", options: .regularExpression) != nil
            
        let score = [hasUppercase, hasLowercase, hasDigit, hasSpecial].filter { $0 }.count
        return score >= 3
    }
}

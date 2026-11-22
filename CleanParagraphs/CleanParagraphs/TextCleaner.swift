import Foundation

enum Language: String, CaseIterable, Identifiable{
    case hungarian = "hu"
    case english = "en"
    case german = "de"
    
    var id: String { rawValue}
    
    var displayName: String {
            switch self {
            case .hungarian: return "Magyar"
            case .english: return "English"
            case .german: return "Deutsch"
            }
        }
        
        var alphabetRegex: String {
            switch self {
            case .hungarian: return "a-záéíóöőúüűA-ZÁÉÍÓÖŐÚÜŰ"
            case .german: return "a-zA-Za-öäüßA-ÖÄÜ"
            case .english: return "a-zA-Z"
            }
        }
    
        var playgroundText: String{
            switch self{
            case .hungarian: return "Ez egy   teszt  szöveg.\n\n\nTöbb soremeléssel  és   szóközzel."
            case .german: return "Dies ist ein   Test  text.\n\n\nMit mehreren Zeilenumbrüchen  und   Leerzeichen."
            case .english: return "This is a   test  text.\n\n\nWith multiple line breaks  and   spaces."
            }
        }
}

struct TextCleaner{
    
    struct Options {
        var language: Language = .hungarian
        var fixWrappedLines: Bool = true
        var collapseMultipleSpaces: Bool = true
        var fixPunctuationSpacing: Bool = true
        var trimLines: Bool = true
        var fixQuotes: Bool = false
        var removeInvisibleChars: Bool = false
    }
    
    static func clean(_ text: String, options: Options = Options()) -> String{
        var result = text
        
        result = result.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.replacingOccurrences(of: "\r", with: "\n")
        
        if options.fixWrappedLines{
            let wrappedLineRegex = options.language.alphabetRegex
            result = result.replacingOccurrences(of: wrappedLineRegex, with: " ", options: .regularExpression)
        }
        
        result = result.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        
        if options.fixPunctuationSpacing {
            result = result.replacingOccurrences(of: #"\s+([.,!?;:])"#, with: "$1", options: .regularExpression)
        }
        
        if options.trimLines || options.collapseMultipleSpaces {
            let lines = result.components(separatedBy: "\n")
            let cleanedLines = lines.map{line -> String in
                var l = line
                if options.collapseMultipleSpaces{
                    l = l.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
                }
                
                if options.trimLines {
                    l = l.trimmingCharacters(in: .whitespaces)
                }
                
                return l
            }
            
            result = cleanedLines.joined(separator: "\n")
        }
        
        if options.removeInvisibleChars {
            result = result.replacingOccurrences(of: "\u{00A0}", with: " ")
            let invisibleCharacters: [Character] = ["\u{200B}", "\u{200C}", "\u{200D}", "\u{FEFF}", "\u{00AD}"]
            result.removeAll{invisibleCharacters.contains($0)}
        }
        
        if options.fixQuotes {
            let quoteMap: [String: String] = ["\u{201E}":"\"", "\u{201C}":"\"", "\u{201D}":"\""]
            for (target, replacement) in quoteMap {
                result = result.replacingOccurrences(of: target, with: replacement)
            }
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
}

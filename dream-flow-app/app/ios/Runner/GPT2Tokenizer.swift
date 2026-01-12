import Foundation

/// GPT-2 tokenizer implementation for Swift
class GPT2Tokenizer {
    private var vocab: [String: Int]?
    private var idToToken: [Int: String]?
    private var merges: [String: [Int]]?
    let unkToken: String = "<|endoftext|>"
    let eosToken: String = "<|endoftext|>"
    let bosToken: String = "<|endoftext|>"
    private let padToken: String? = nil
    
    
    private init(vocab: [String: Int]?, idToToken: [Int: String]?) {
        self.vocab = vocab
        self.idToToken = idToToken
    }
    
    /// Load tokenizer from bundle or documents
    static func load() throws -> GPT2Tokenizer {
        // Try loading from bundle first
        if let bundlePath = Bundle.main.path(forResource: "tokenizer", ofType: "json", inDirectory: "Tokenizers"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: bundlePath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return try fromJSON(json: json)
        }
        
        // Try loading from documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let tokenizerPath = documentsPath.appendingPathComponent("tokenizers/tokenizer.json")
        
        if FileManager.default.fileExists(atPath: tokenizerPath.path),
           let data = try? Data(contentsOf: tokenizerPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return try fromJSON(json: json)
        }
        
        // Fallback: create simple tokenizer
        return createSimple()
    }
    
    /// Create tokenizer from JSON
    static func fromJSON(json: [String: Any]) throws -> GPT2Tokenizer {
        var vocab: [String: Int] = [:]
        var idToToken: [Int: String] = [:]
        
        // Extract vocabulary
        if let vocabDict = json["vocab"] as? [String: Any] {
            for (key, value) in vocabDict {
                if let id = value as? Int {
                    vocab[key] = id
                    idToToken[id] = key
                } else if let idString = value as? String, let id = Int(idString) {
                    vocab[key] = id
                    idToToken[id] = key
                }
            }
        }
        
        return GPT2Tokenizer(vocab: vocab, idToToken: idToToken)
    }
    
    /// Create simple fallback tokenizer
    static func createSimple() -> GPT2Tokenizer {
        return GPT2Tokenizer(vocab: nil, idToToken: nil)
    }
    
    /// Encode text to token IDs
    func encode(_ text: String) -> [Int] {
        guard let vocab = vocab else {
            return simpleEncode(text)
        }
        
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        var tokens: [Int] = []
        
        for word in words {
            if let tokenId = vocab[word] {
                tokens.append(tokenId)
            } else {
                // Try splitting word into subwords
                let subwords = splitWord(word)
                for subword in subwords {
                    if let tokenId = vocab[subword] {
                        tokens.append(tokenId)
                    } else if let unkId = vocab[unkToken] {
                        tokens.append(unkId)
                    }
                }
            }
        }
        
        // Add EOS token
        if let eosId = vocab[eosToken] {
            tokens.append(eosId)
        }
        
        return tokens.isEmpty ? [0] : tokens
    }
    
    /// Simple word-level encoding (fallback)
    private func simpleEncode(_ text: String) -> [Int] {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        return words.map { abs($0.hashValue) % 50000 }
    }
    
    /// Split word into subwords
    private func splitWord(_ word: String) -> [String] {
        if word.count <= 3 {
            return [word]
        }
        
        var subwords: [String] = []
        var index = word.startIndex
        
        while index < word.endIndex {
            let remaining = word.distance(from: index, to: word.endIndex)
            let length = min(4, remaining)
            let endIndex = word.index(index, offsetBy: length)
            subwords.append(String(word[index..<endIndex]))
            index = endIndex
        }
        
        return subwords
    }
    
    /// Decode token IDs to text
    func decode(_ tokenIds: [Int]) -> String {
        guard let idToToken = idToToken else {
            return simpleDecode(tokenIds)
        }
        
        var tokens: [String] = []
        for id in tokenIds {
            if let token = idToToken[id] {
                // Skip special tokens
                if token != eosToken && token != bosToken && token != padToken &&
                   !token.hasPrefix("<|") && !token.hasSuffix("|>") {
                    tokens.append(token)
                }
            }
        }
        
        var text = tokens.joined(separator: " ")
        // Remove BPE markers
        text = text.replacingOccurrences(of: "##", with: "")
        // Clean up spacing
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Simple word-level decoding (fallback)
    private func simpleDecode(_ tokenIds: [Int]) -> String {
        return tokenIds.map { "word\($0)" }.joined(separator: " ")
    }
    
    /// Get vocabulary size
    var vocabSize: Int {
        return vocab?.count ?? 50257
    }
    
    /// Get vocabulary dictionary (for EOS token lookup)
    func getVocab() -> [String: Int]? {
        return vocab
    }
}


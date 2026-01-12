import Foundation
import CoreML
import NaturalLanguage

/// Core ML Story Generator for on-device text generation
/// Uses Neural Engine acceleration on A12+ devices
class CoreMLStoryGenerator: NSObject {
    private var model: MLModel?
    private var modelLoaded = false
    
    // Tokenizer for text processing
    private var tokenizer: NLTokenizer?
    private var vocabulary: [String: Int] = [:]
    private var reverseVocabulary: [Int: String] = [:]
    
    /// Load the Core ML story generation model
    /// Expects gpt2_tiny.mlmodelc in Resources/Models/
    func loadModel() throws {
        if modelLoaded {
            print("CoreML Story model already loaded")
            return
        }
        
        // Try to load from bundle
        guard let modelURL = Bundle.main.url(
            forResource: "gpt2_tiny",
            withExtension: "mlmodelc"
        ) else {
            // Fallback: try .mlmodel extension
            guard let fallbackURL = Bundle.main.url(
                forResource: "gpt2_tiny",
                withExtension: "mlmodel"
            ) else {
                throw NSError(
                    domain: "CoreMLStoryGenerator",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Model file not found in bundle"]
                )
            }
            model = try MLModel(contentsOf: fallbackURL)
            modelLoaded = true
            print("CoreML Story model loaded from .mlmodel")
            return
        }
        
        // Load compiled model
        let config = MLModelConfiguration()
        config.computeUnits = .all // Use Neural Engine + GPU + CPU
        
        model = try MLModel(contentsOf: modelURL, configuration: config)
        modelLoaded = true
        
        // Initialize tokenizer
        tokenizer = NLTokenizer(unit: .word)
        
        print("✓ CoreML Story model loaded successfully (Neural Engine enabled)")
    }
    
    /// Generate story text from prompt
    /// - Parameters:
    ///   - prompt: Input prompt text
    ///   - maxTokens: Maximum number of tokens to generate
    ///   - temperature: Sampling temperature (0.0-1.0)
    /// - Returns: Generated story text
    func generate(prompt: String, maxTokens: Int, temperature: Double = 0.8) throws -> String {
        guard modelLoaded, let model = model else {
            throw NSError(
                domain: "CoreMLStoryGenerator",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Model not loaded"]
            )
        }
        
        print("🎯 CoreML Story generation started")
        print("   Prompt: \(prompt.prefix(50))...")
        print("   Max tokens: \(maxTokens)")
        
        // For now, return placeholder until we have actual model files
        // This allows the infrastructure to be tested
        let placeholder = """
        Once upon a time, there was a wonderful story about \(prompt).
        
        The tale unfolds gently, carrying the listener on a peaceful journey through imagination.
        As the stars twinkled above, everything felt calm and serene.
        
        [Core ML inference will be completed when model files are bundled]
        """
        
        print("✓ CoreML Story generation completed (placeholder mode)")
        return placeholder
        
        // TODO: Implement actual inference when model is available
        // Steps:
        // 1. Tokenize input prompt
        // 2. Convert to input tensor format
        // 3. Run model.prediction() iteratively
        // 4. Sample next token with temperature
        // 5. Decode tokens back to text
        // 6. Return generated story
    }
    
    /// Check if model is loaded and ready
    func isLoaded() -> Bool {
        return modelLoaded
    }
    
    /// Unload model and free resources
    func unload() {
        model = nil
        tokenizer = nil
        modelLoaded = false
        print("CoreML Story model unloaded")
    }
    
    // MARK: - Private Helper Methods
    
    /// Tokenize text into token IDs
    private func tokenize(_ text: String) -> [Int] {
        guard let tokenizer = tokenizer else { return [] }
        
        tokenizer.string = text
        var tokens: [Int] = []
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let token = String(text[range])
            if let tokenId = vocabulary[token] {
                tokens.append(tokenId)
            }
            return true
        }
        
        return tokens
    }
    
    /// Decode token IDs back to text
    private func decode(_ tokens: [Int]) -> String {
        var words: [String] = []
        for tokenId in tokens {
            if let word = reverseVocabulary[tokenId] {
                words.append(word)
            }
        }
        return words.joined(separator: " ")
    }
    
    /// Load vocabulary from bundle
    private func loadVocabulary() throws {
        guard let vocabURL = Bundle.main.url(
            forResource: "vocab",
            withExtension: "json"
        ) else {
            print("⚠️ Vocabulary file not found, using placeholder tokenization")
            return
        }
        
        let data = try Data(contentsOf: vocabURL)
        vocabulary = try JSONDecoder().decode([String: Int].self, from: data)
        
        // Build reverse vocabulary
        for (word, id) in vocabulary {
            reverseVocabulary[id] = word
        }
        
        print("✓ Loaded vocabulary with \(vocabulary.count) tokens")
    }
}

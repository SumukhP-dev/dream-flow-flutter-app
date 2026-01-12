import Foundation
import CoreML
import CoreImage
import CoreGraphics
import Accelerate

/// Core ML Image Generator for on-device Stable Diffusion
/// Uses Neural Engine acceleration on A12+ devices
class CoreMLImageGenerator: NSObject {
    private var textEncoder: MLModel?
    private var unet: MLModel?
    private var vaeDecoder: MLModel?
    private var modelLoaded = false
    
    // Image generation parameters
    private let defaultWidth = 384
    private let defaultHeight = 384
    private let latentChannels = 4
    
    /// Load Core ML Stable Diffusion models
    /// Expects compiled models in Resources/Models/
    func loadModel() throws {
        if modelLoaded {
            print("CoreML Image models already loaded")
            return
        }
        
        let config = MLModelConfiguration()
        config.computeUnits = .all // Use Neural Engine + GPU + CPU
        
        // Try to load text encoder
        guard let textEncoderURL = Bundle.main.url(
            forResource: "sd_text_encoder",
            withExtension: "mlmodelc"
        ) else {
            throw NSError(
                domain: "CoreMLImageGenerator",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Text encoder model not found in bundle"]
            )
        }
        
        // Try to load UNet
        guard let unetURL = Bundle.main.url(
            forResource: "sd_unet",
            withExtension: "mlmodelc"
        ) else {
            throw NSError(
                domain: "CoreMLImageGenerator",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "UNet model not found in bundle"]
            )
        }
        
        // Try to load VAE decoder
        guard let vaeURL = Bundle.main.url(
            forResource: "sd_vae_decoder",
            withExtension: "mlmodelc"
        ) else {
            throw NSError(
                domain: "CoreMLImageGenerator",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "VAE decoder model not found in bundle"]
            )
        }
        
        // Load all models
        textEncoder = try MLModel(contentsOf: textEncoderURL, configuration: config)
        unet = try MLModel(contentsOf: unetURL, configuration: config)
        vaeDecoder = try MLModel(contentsOf: vaeURL, configuration: config)
        
        modelLoaded = true
        print("✓ CoreML Stable Diffusion models loaded successfully")
        print("  - Text Encoder: ✓")
        print("  - UNet: ✓")
        print("  - VAE Decoder: ✓")
        print("  - Neural Engine enabled")
    }
    
    /// Generate images from text prompt
    /// - Parameters:
    ///   - prompt: Text description of desired image
    ///   - numImages: Number of images to generate (1-4)
    ///   - width: Image width (default 384)
    ///   - height: Image height (default 384)
    ///   - numInferenceSteps: Denoising steps (default 10)
    ///   - guidanceScale: Classifier-free guidance scale (default 7.5)
    /// - Returns: Array of PNG image data
    func generate(
        prompt: String,
        numImages: Int = 4,
        width: Int = 384,
        height: Int = 384,
        numInferenceSteps: Int = 10,
        guidanceScale: Double = 7.5
    ) throws -> [Data] {
        guard modelLoaded else {
            throw NSError(
                domain: "CoreMLImageGenerator",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Models not loaded"]
            )
        }
        
        print("🎨 CoreML Image generation started")
        print("   Prompt: \(prompt.prefix(50))...")
        print("   Images: \(numImages), Size: \(width)x\(height)")
        print("   Steps: \(numInferenceSteps)")
        
        var generatedImages: [Data] = []
        
        // For now, return placeholder images until we have actual model files
        // This allows the infrastructure to be tested
        for i in 0..<numImages {
            let placeholderImage = createPlaceholderImage(
                width: width,
                height: height,
                index: i,
                prompt: prompt
            )
            if let pngData = placeholderImage.pngData() {
                generatedImages.append(pngData)
            }
        }
        
        print("✓ CoreML Image generation completed (\(generatedImages.count) images, placeholder mode)")
        return generatedImages
        
        // TODO: Implement actual Stable Diffusion pipeline when models are available
        // Steps:
        // 1. Encode text prompt with text encoder
        // 2. Initialize random latent tensor
        // 3. Run denoising loop with UNet
        // 4. Decode latents with VAE
        // 5. Post-process to image format
        // 6. Return PNG data
    }
    
    /// Check if models are loaded and ready
    func isLoaded() -> Bool {
        return modelLoaded
    }
    
    /// Unload models and free resources
    func unload() {
        textEncoder = nil
        unet = nil
        vaeDecoder = nil
        modelLoaded = false
        print("CoreML Image models unloaded")
    }
    
    // MARK: - Private Helper Methods
    
    /// Create a placeholder image for testing
    private func createPlaceholderImage(
        width: Int,
        height: Int,
        index: Int,
        prompt: String
    ) -> UIImage {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // Background gradient
            let colors = [
                UIColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1.0),
                UIColor(red: 0.4, green: 0.2, blue: 0.6, alpha: 1.0)
            ]
            
            let startPoint = CGPoint(x: 0, y: 0)
            let endPoint = CGPoint(x: size.width, y: size.height)
            
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors.map { $0.cgColor } as CFArray,
                locations: [0.0, 1.0]
            ) {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: startPoint,
                    end: endPoint,
                    options: []
                )
            }
            
            // Text overlay
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.8),
                .paragraphStyle: paragraphStyle
            ]
            
            let text = "Image \(index + 1)\n\(prompt.prefix(30))..."
            let textRect = CGRect(
                x: 20,
                y: (size.height - 100) / 2,
                width: size.width - 40,
                height: 100
            )
            text.draw(in: textRect, withAttributes: attributes)
        }
        
        return image
    }
    
    /// Encode text prompt to embeddings
    private func encodePrompt(_ prompt: String) throws -> MLMultiArray {
        guard let textEncoder = textEncoder else {
            throw NSError(
                domain: "CoreMLImageGenerator",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Text encoder not loaded"]
            )
        }
        
        // TODO: Tokenize prompt and run through text encoder
        // Return shape: [1, 77, 768] for Stable Diffusion
        
        // Placeholder return
        let shape = [1, 77, 768] as [NSNumber]
        let array = try MLMultiArray(shape: shape, dataType: .float32)
        return array
    }
    
    /// Run denoising loop
    private func denoise(
        latents: MLMultiArray,
        textEmbeddings: MLMultiArray,
        numSteps: Int,
        guidanceScale: Double
    ) throws -> MLMultiArray {
        guard let unet = unet else {
            throw NSError(
                domain: "CoreMLImageGenerator",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "UNet not loaded"]
            )
        }
        
        var currentLatents = latents
        
        for step in 0..<numSteps {
            // TODO: Run UNet prediction
            // Apply scheduler step
            // Update latents
            print("  Denoising step \(step + 1)/\(numSteps)")
        }
        
        return currentLatents
    }
    
    /// Decode latents to image
    private func decodeLatents(_ latents: MLMultiArray) throws -> UIImage {
        guard let vaeDecoder = vaeDecoder else {
            throw NSError(
                domain: "CoreMLImageGenerator",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "VAE decoder not loaded"]
            )
        }
        
        // TODO: Run VAE decoder
        // Convert output to UIImage
        // Return decoded image
        
        // Placeholder return
        return createPlaceholderImage(
            width: defaultWidth,
            height: defaultHeight,
            index: 0,
            prompt: "Decoded"
        )
    }
}

// MARK: - UIImage PNG Extension
extension UIImage {
    func pngData() -> Data? {
        return self.pngData()
    }
}

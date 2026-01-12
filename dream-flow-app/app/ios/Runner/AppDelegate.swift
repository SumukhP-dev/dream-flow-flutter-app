// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  private let ML_CHANNEL = "com.dreamflow/ml"
  
  // Core ML model instances
  private let storyGenerator = CoreMLStoryGenerator()
  private let imageGenerator = CoreMLImageGenerator()
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    
    // Register ML method channel
    let mlChannel = FlutterMethodChannel(
      name: ML_CHANNEL,
      binaryMessenger: controller.binaryMessenger
    )
    
    mlChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else {
        result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate not available", details: nil))
        return
      }
      
      switch call.method {
      // Story Generation Methods
      case "loadStoryModel":
        self.loadStoryModel(result: result)
        
      case "generateStory":
        guard let args = call.arguments as? [String: Any],
              let prompt = args["prompt"] as? String,
              let maxTokens = args["maxTokens"] as? Int else {
          result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
          return
        }
        let temperature = args["temperature"] as? Double ?? 0.8
        self.generateStory(prompt: prompt, maxTokens: maxTokens, temperature: temperature, result: result)
        
      case "unloadStoryModel":
        self.unloadStoryModel(result: result)
        
      case "isStoryModelLoaded":
        result(self.storyGenerator.isLoaded())
        
      // Image Generation Methods
      case "loadImageModel":
        self.loadImageModel(result: result)
        
      case "generateImages":
        guard let args = call.arguments as? [String: Any],
              let prompt = args["prompt"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
          return
        }
        let numImages = args["numImages"] as? Int ?? 4
        let width = args["width"] as? Int ?? 384
        let height = args["height"] as? Int ?? 384
        let numInferenceSteps = args["numInferenceSteps"] as? Int ?? 10
        let guidanceScale = args["guidanceScale"] as? Double ?? 7.5
        
        self.generateImages(
          prompt: prompt,
          numImages: numImages,
          width: width,
          height: height,
          numInferenceSteps: numInferenceSteps,
          guidanceScale: guidanceScale,
          result: result
        )
        
      case "unloadImageModel":
        self.unloadImageModel(result: result)
        
      case "isImageModelLoaded":
        result(self.imageGenerator.isLoaded())
        
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: - Story Generation Methods
  
  private func loadStoryModel(result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try self.storyGenerator.loadModel()
        DispatchQueue.main.async {
          result(true)
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "MODEL_LOAD_ERROR",
            message: "Failed to load story model: \(error.localizedDescription)",
            details: nil
          ))
        }
      }
    }
  }
  
  private func generateStory(
    prompt: String,
    maxTokens: Int,
    temperature: Double,
    result: @escaping FlutterResult
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let story = try self.storyGenerator.generate(
          prompt: prompt,
          maxTokens: maxTokens,
          temperature: temperature
        )
        DispatchQueue.main.async {
          result(story)
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "GENERATION_ERROR",
            message: "Failed to generate story: \(error.localizedDescription)",
            details: nil
          ))
        }
      }
    }
  }
  
  private func unloadStoryModel(result: @escaping FlutterResult) {
    storyGenerator.unload()
    result(true)
  }
  
  // MARK: - Image Generation Methods
  
  private func loadImageModel(result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try self.imageGenerator.loadModel()
        DispatchQueue.main.async {
          result(true)
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "MODEL_LOAD_ERROR",
            message: "Failed to load image model: \(error.localizedDescription)",
            details: nil
          ))
        }
      }
    }
  }
  
  private func generateImages(
    prompt: String,
    numImages: Int,
    width: Int,
    height: Int,
    numInferenceSteps: Int,
    guidanceScale: Double,
    result: @escaping FlutterResult
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let images = try self.imageGenerator.generate(
          prompt: prompt,
          numImages: numImages,
          width: width,
          height: height,
          numInferenceSteps: numInferenceSteps,
          guidanceScale: guidanceScale
        )
        
        // Convert Data array to FlutterStandardTypedData array
        let flutterImages = images.map { imageData in
          FlutterStandardTypedData(bytes: imageData)
        }
        
        DispatchQueue.main.async {
          result(flutterImages)
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "GENERATION_ERROR",
            message: "Failed to generate images: \(error.localizedDescription)",
            details: nil
          ))
        }
      }
    }
  }
  
  private func unloadImageModel(result: @escaping FlutterResult) {
    imageGenerator.unload()
    result(true)
  }
}

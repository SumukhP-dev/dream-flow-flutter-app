import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'gpt2_tokenizer.dart';

/// Manager for loading and caching tokenizers
class TokenizerManager {
  static TokenizerManager? _instance;
  static TokenizerManager get instance => _instance ??= TokenizerManager._();

  TokenizerManager._();

  GPT2Tokenizer? _gpt2Tokenizer;

  /// Load GPT-2 tokenizer (cached)
  Future<GPT2Tokenizer> loadGPT2Tokenizer() async {
    if (_gpt2Tokenizer != null) {
      return _gpt2Tokenizer!;
    }

    try {
      // Try loading from assets first
      try {
        _gpt2Tokenizer = await _loadFromAssets();
        debugPrint('GPT-2 tokenizer loaded from assets');
        return _gpt2Tokenizer!;
      } catch (e) {
        debugPrint('Failed to load tokenizer from assets: $e');
      }

      // Fallback: try loading from documents directory
      try {
        _gpt2Tokenizer = await _loadFromDocuments();
        debugPrint('GPT-2 tokenizer loaded from documents');
        return _gpt2Tokenizer!;
      } catch (e) {
        debugPrint('Failed to load tokenizer from documents: $e');
      }

      // Last resort: create a simple tokenizer
      debugPrint('Creating simple fallback tokenizer');
      _gpt2Tokenizer = GPT2Tokenizer.createSimple();
      return _gpt2Tokenizer!;
    } catch (e) {
      debugPrint('Error loading tokenizer: $e');
      // Return simple tokenizer as fallback
      _gpt2Tokenizer = GPT2Tokenizer.createSimple();
      return _gpt2Tokenizer!;
    }
  }

  /// Load tokenizer from assets
  Future<GPT2Tokenizer> _loadFromAssets() async {
    try {
      // Try loading tokenizer.json from assets
      final tokenizerJson = await rootBundle.loadString('assets/tokenizers/tokenizer.json');
      
      // Try loading vocab.json from assets
      String? vocabJson;
      try {
        vocabJson = await rootBundle.loadString('assets/tokenizers/vocab.json');
      } catch (e) {
        debugPrint('vocab.json not found in assets, will parse from tokenizer.json');
      }

      return GPT2Tokenizer.fromJson(tokenizerJson, vocabJson: vocabJson);
    } catch (e) {
      throw Exception('Failed to load tokenizer from assets: $e');
    }
  }

  /// Load tokenizer from documents directory
  Future<GPT2Tokenizer> _loadFromDocuments() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final tokenizerPath = path.join(appDir.path, 'tokenizers', 'tokenizer.json');
      final vocabPath = path.join(appDir.path, 'tokenizers', 'vocab.json');

      final tokenizerFile = File(tokenizerPath);
      if (!await tokenizerFile.exists()) {
        throw Exception('tokenizer.json not found at $tokenizerPath');
      }

      final tokenizerJson = await tokenizerFile.readAsString();
      
      String? vocabJson;
      final vocabFile = File(vocabPath);
      if (await vocabFile.exists()) {
        vocabJson = await vocabFile.readAsString();
      }

      return GPT2Tokenizer.fromJson(tokenizerJson, vocabJson: vocabJson);
    } catch (e) {
      throw Exception('Failed to load tokenizer from documents: $e');
    }
  }

  /// Clear cached tokenizer
  void clearCache() {
    _gpt2Tokenizer = null;
  }
}


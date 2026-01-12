import 'dart:convert';
import 'package:flutter/foundation.dart';

/// GPT-2 tokenizer implementation
/// Supports loading from tokenizer.json (Hugging Face format)
/// Falls back to simple word-level tokenization if files not available
class GPT2Tokenizer {
  final Map<String, int>? vocab;
  final Map<int, String>? idToToken;
  final Map<String, List<int>>? merges;
  final String? unkToken;
  final String? bosToken;
  final String? eosToken;
  final String? padToken;
  final bool isSimple;

  GPT2Tokenizer._({
    this.vocab,
    this.idToToken,
    this.merges,
    this.unkToken,
    this.bosToken,
    this.eosToken,
    this.padToken,
    this.isSimple = false,
  });

  /// Create a simple word-level tokenizer (fallback)
  factory GPT2Tokenizer.createSimple() {
    return GPT2Tokenizer._(isSimple: true);
  }

  /// Load tokenizer from JSON (Hugging Face format)
  factory GPT2Tokenizer.fromJson(String tokenizerJson, {String? vocabJson}) {
    try {
      final tokenizerData = json.decode(tokenizerJson) as Map<String, dynamic>;
      
      // Extract vocabulary
      Map<String, int>? vocab;
      Map<int, String>? idToToken;
      
      if (vocabJson != null) {
        final vocabData = json.decode(vocabJson) as Map<String, dynamic>;
        vocab = {};
        idToToken = {};
        
        vocabData.forEach((key, value) {
          final id = value is int ? value : int.parse(value.toString());
          vocab![key] = id;
          idToToken![id] = key;
        });
      } else if (tokenizerData.containsKey('vocab')) {
        final vocabData = tokenizerData['vocab'] as Map<String, dynamic>;
        vocab = {};
        idToToken = {};
        
        vocabData.forEach((key, value) {
          final id = value is int ? value : int.parse(value.toString());
          vocab![key] = id;
          idToToken![id] = key;
        });
      }

      // Extract merges (BPE merges)
      Map<String, List<int>>? merges;
      if (tokenizerData.containsKey('merges')) {
        final mergesList = tokenizerData['merges'] as List<dynamic>;
        merges = {};
        for (int i = 0; i < mergesList.length; i++) {
          final merge = mergesList[i] as String;
          final parts = merge.split(' ');
          if (parts.length == 2) {
            final token1 = parts[0];
            final token2 = parts[1];
            final mergedToken = token1 + token2;
            if (vocab != null && vocab.containsKey(token1) && vocab.containsKey(token2)) {
              final token1Id = vocab[token1]!;
              final token2Id = vocab[token2]!;
              merges[mergedToken] = [token1Id, token2Id];
            }
          }
        }
      }

      // Extract special tokens
      final addedTokens = tokenizerData['added_tokens'] as List<dynamic>?;
      String? unkToken, bosToken, eosToken, padToken;
      
      if (addedTokens != null) {
        for (final token in addedTokens) {
          final tokenMap = token as Map<String, dynamic>;
          final content = tokenMap['content'] as String?;
          final special = tokenMap['special'] as bool? ?? false;
          
          if (special && content != null) {
            if (content == '<|endoftext|>') {
              eosToken = content;
            } else if (content.contains('unk') || content.contains('UNK')) {
              unkToken = content;
            } else if (content.contains('bos') || content.contains('BOS')) {
              bosToken = content;
            } else if (content.contains('pad') || content.contains('PAD')) {
              padToken = content;
            }
          }
        }
      }

      // Default special tokens for GPT-2
      unkToken ??= '<|endoftext|>';
      eosToken ??= '<|endoftext|>';
      bosToken ??= '<|endoftext|>';

      return GPT2Tokenizer._(
        vocab: vocab,
        idToToken: idToToken,
        merges: merges,
        unkToken: unkToken,
        eosToken: eosToken,
        bosToken: bosToken,
        padToken: padToken,
      );
    } catch (e) {
      debugPrint('Error parsing tokenizer JSON: $e');
      // Fallback to simple tokenizer
      return GPT2Tokenizer.createSimple();
    }
  }

  /// Encode text to token IDs
  List<int> encode(String text) {
    if (isSimple || vocab == null) {
      return _simpleEncode(text);
    }

    try {
      // Simple BPE-like encoding (simplified version)
      // In production, use proper BPE algorithm
      final tokens = <int>[];
      final words = text.toLowerCase().split(RegExp(r'\s+'));
      
      for (final word in words) {
        if (vocab!.containsKey(word)) {
          tokens.add(vocab![word]!);
        } else {
          // Try to split word into subwords
          final subwords = _splitWord(word);
          for (final subword in subwords) {
            if (vocab!.containsKey(subword)) {
              tokens.add(vocab![subword]!);
            } else if (unkToken != null && vocab!.containsKey(unkToken!)) {
              tokens.add(vocab![unkToken!]!);
            }
          }
        }
      }

      // Add EOS token
      if (eosToken != null && vocab!.containsKey(eosToken!)) {
        tokens.add(vocab![eosToken!]!);
      }

      return tokens.isEmpty ? [0] : tokens;
    } catch (e) {
      debugPrint('Error encoding text: $e');
      return _simpleEncode(text);
    }
  }

  /// Simple word-level encoding (fallback)
  List<int> _simpleEncode(String text) {
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    final tokens = <int>[];
    
    // Simple hash-based tokenization
    for (final word in words) {
      final hash = word.hashCode;
      tokens.add(hash.abs() % 50000); // Limit to reasonable vocab size
    }
    
    return tokens.isEmpty ? [0] : tokens;
  }

  /// Split word into subwords (simple implementation)
  List<String> _splitWord(String word) {
    if (word.length <= 3) {
      return [word];
    }
    
    final subwords = <String>[];
    int i = 0;
    while (i < word.length) {
      int len = word.length - i > 4 ? 4 : word.length - i;
      subwords.add(word.substring(i, i + len));
      i += len;
    }
    return subwords;
  }

  /// Decode token IDs to text
  String decode(List<int> tokenIds) {
    if (isSimple || idToToken == null) {
      return _simpleDecode(tokenIds);
    }

    try {
      final tokens = <String>[];
      for (final id in tokenIds) {
        if (idToToken!.containsKey(id)) {
          final token = idToToken![id]!;
          // Skip special tokens in output
          if (token != eosToken && 
              token != bosToken && 
              token != padToken &&
              !token.startsWith('<|') && 
              !token.endsWith('|>')) {
            tokens.add(token);
          }
        }
      }
      
      // Join tokens and clean up
      var text = tokens.join(' ');
      // Remove BPE markers (##)
      text = text.replaceAll('##', '');
      // Clean up spacing
      text = text.replaceAll(RegExp(r'\s+'), ' ');
      return text.trim();
    } catch (e) {
      debugPrint('Error decoding tokens: $e');
      return _simpleDecode(tokenIds);
    }
  }

  /// Simple word-level decoding (fallback)
  String _simpleDecode(List<int> tokenIds) {
    // Simple fallback - just return a placeholder
    // In production, this would maintain a reverse mapping
    return tokenIds.map((id) => 'word$id').join(' ');
  }

  /// Get vocabulary size
  int get vocabSize => vocab?.length ?? 50257; // Default GPT-2 vocab size
}


import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/subscription_service.dart';
import '../core/auth_service.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  final AuthService _authService = AuthService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  
  static const String _keyStoryCounter = 'ad_story_counter';
  static const String _keyLastAdResetDate = 'ad_last_reset_date';
  static const int interstitialFrequency = 5;
  static const int dailyFreeLimit = 2;

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _isInterstitialLoading = false;
  bool _isRewardedLoading = false;

  // Test Ad Unit IDs
  String get bannerAdUnitId {
    if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/6300978111';
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/2934735716';
    return '';
  }

  String get nativeAdUnitId {
    if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/2247696110';
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/3986624511';
    return '';
  }

  String get interstitialAdUnitId {
    if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/1033173712';
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/4411468910';
    return '';
  }

  String get rewardedAdUnitId {
    if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/5224354917';
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/1712485313';
    return '';
  }

  Future<bool> isUserPremium() async {
    if (!_authService.isLoggedIn) return false;
    try {
      final sub = await _subscriptionService.getSubscription();
      return sub.isPremium;
    } catch (e) {
      debugPrint('Error checking premium status: $e');
      return false;
    }
  }

  // Story Counter Logic
  Future<int> getStoryCounter() async {
    final prefs = await SharedPreferences.getInstance();
    await _checkAndResetDailyCounter(prefs);
    return prefs.getInt(_keyStoryCounter) ?? 0;
  }

  Future<void> incrementStoryCounter() async {
    final prefs = await SharedPreferences.getInstance();
    await _checkAndResetDailyCounter(prefs);
    final current = prefs.getInt(_keyStoryCounter) ?? 0;
    await prefs.setInt(_keyStoryCounter, current + 1);
  }

  Future<void> _checkAndResetDailyCounter(SharedPreferences prefs) async {
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';
    final lastReset = prefs.getString(_keyLastAdResetDate);

    if (lastReset != today) {
      await prefs.setInt(_keyStoryCounter, 0);
      await prefs.setString(_keyLastAdResetDate, today);
    }
  }

  Future<bool> hasReachedDailyFreeLimit() async {
    if (await isUserPremium()) return false;
    final counter = await getStoryCounter();
    return counter >= dailyFreeLimit;
  }

  // Interstitial Ads
  void loadInterstitialAd() {
    if (_isInterstitialLoading || _interstitialAd != null) return;
    _isInterstitialLoading = true;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
        },
        onAdFailedToLoad: (err) {
          debugPrint('InterstitialAd failed to load: $err');
          _isInterstitialLoading = false;
        },
      ),
    );
  }

  Future<void> showInterstitialIfEligible() async {
    if (await isUserPremium()) return;

    final counter = await getStoryCounter();
    if (counter > 0 && counter % interstitialFrequency == 0) {
      if (_interstitialAd != null) {
        _interstitialAd!.show();
        _interstitialAd = null;
        loadInterstitialAd(); // Preload next
      } else {
        loadInterstitialAd();
      }
    }
  }

  // Rewarded Ads
  void loadRewardedAd() {
    if (_isRewardedLoading || _rewardedAd != null) return;
    _isRewardedLoading = true;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
        },
        onAdFailedToLoad: (err) {
          debugPrint('RewardedAd failed to load: $err');
          _isRewardedLoading = false;
        },
      ),
    );
  }

  Future<bool> showRewardedAd() async {
    if (_rewardedAd == null) {
      loadRewardedAd();
      return false;
    }

    bool rewarded = false;
    await _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
      rewarded = true;
    });
    
    _rewardedAd = null;
    loadRewardedAd(); // Preload next
    return rewarded;
  }

  // Native Ads
  NativeAd createNativeAd({
    required void Function(Ad) onAdLoaded,
    required void Function(Ad, LoadAdError) onAdFailedToLoad,
  }) {
    return NativeAd(
      adUnitId: nativeAdUnitId,
      factoryId: 'listTile', // Requires native setup if using custom factory
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onAdFailedToLoad(ad, error);
        },
      ),
    )..load();
  }
}

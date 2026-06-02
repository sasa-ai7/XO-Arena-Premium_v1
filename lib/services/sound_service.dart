import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService with WidgetsBindingObserver {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._();

  final AudioPlayer _bgmPlayer = AudioPlayer(playerId: 'bgmPlayer');
  Future<void>? _initFuture;
  StreamSubscription<PlayerState>? _playerStateSub;
  bool _observerAttached = false;
  bool _isInitialized = false;
  bool _isMusicEnabled = true;
  double _musicVolume = 0.7;
  double _duckFactor = 0.10;
  int _duckDepth = 0;
  PlayerState _playerState = PlayerState.stopped;
  bool _startInProgress = false;
  bool _pausedByLifecycle = false;

  bool get isMusicEnabled => _isMusicEnabled;
  double get musicVolume => _musicVolume;

  double get _effectiveMusicVolume {
    if (!_isMusicEnabled) return 0.0;
    return (_duckDepth > 0 ? _musicVolume * _duckFactor : _musicVolume)
        .clamp(0.0, 1.0);
  }

  Future<void> _applyMusicVolume() async {
    try {
      await _bgmPlayer.setVolume(_effectiveMusicVolume);
    } catch (e) {
      debugPrint('[SoundService] setVolume failed: $e');
    }
  }

  Future<void> init() {
    // Skip if already fully initialized
    if (_isInitialized) return Future.value();
    // Otherwise use existing dedup or start new init
    return _initFuture ??= _initInternal();
  }

  Future<void> _initInternal() async {
    if (!_observerAttached) {
      WidgetsBinding.instance.addObserver(this);
      _observerAttached = true;
    }

    _playerStateSub ??= _bgmPlayer.onPlayerStateChanged.listen((state) {
      _playerState = state;
    });

    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: false,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('[SoundService] global audio context failed: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    _isMusicEnabled = prefs.getBool('musicEnabled') ?? true;
    _musicVolume = prefs.getDouble('musicVolume') ?? 0.7;
    await prefs.remove('sfxEnabled');
    await prefs.remove('sfxVolume');
    _duckDepth = 0;
    _duckFactor = 0.10;

    if (kDebugMode) {
      debugPrint('[MUSIC] prefs loaded — musicEnabled=$_isMusicEnabled musicVolume=$_musicVolume');
    }

    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    } catch (e) {
      debugPrint('[SoundService] setReleaseMode failed: $e');
    }

    _isInitialized = true;
    await _applyMusicVolume();

    if (kDebugMode) {
      debugPrint('[MUSIC] init complete — starting music: $_isMusicEnabled');
    }

    if (_isMusicEnabled) {
      await ensureMusicPlaying(forceRestart: true);
    }
  }

  Future<void> ensureMusicPlaying({bool forceRestart = false}) async {
    if (!_isInitialized) {
      await init();
    }
    if (!_isMusicEnabled) {
      await stopMusic();
      return;
    }
    if (_startInProgress) return;

    if (!forceRestart && _playerState == PlayerState.playing) {
      await _applyMusicVolume();
      return;
    }

    if (!forceRestart && _playerState == PlayerState.paused) {
      try {
        await _bgmPlayer.resume();
        await _applyMusicVolume();
        return;
      } catch (e) {
        debugPrint('[SoundService] resume fallback failed: $e');
      }
    }

    await startMusic(forceRestart: forceRestart);
  }

  Future<void> startMusic({bool forceRestart = true}) async {
    if (!_isInitialized) {
      await init();
    }
    if (!_isMusicEnabled || _startInProgress) return;

    _startInProgress = true;
    try {
      if (forceRestart || _playerState != PlayerState.stopped) {
        await _bgmPlayer.stop();
      }
      _duckDepth = 0;
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _applyMusicVolume();
      if (kDebugMode) {
        debugPrint('[MUSIC] start requested — volume=$_effectiveMusicVolume');
      }
      await _bgmPlayer.play(AssetSource('music/Sound 1.mp3'));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MUSIC] startMusic error: $e');
      }
      debugPrint('[SoundService] startMusic failed: $e');
    } finally {
      _startInProgress = false;
    }
  }

  Future<void> stopMusic() async {
    if (!_isInitialized) return;
    try {
      await _bgmPlayer.stop();
      _playerState = PlayerState.stopped;
    } catch (e) {
      debugPrint('[SoundService] stopMusic failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized) return;
    if (kDebugMode) {
      debugPrint('[MUSIC] lifecycle: $state — playerState=$_playerState musicEnabled=$_isMusicEnabled');
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_playerState == PlayerState.playing) {
        _pausedByLifecycle = true;
        if (kDebugMode) debugPrint('[MUSIC] paused due to lifecycle');
        unawaited(_bgmPlayer.pause());
      }
      return;
    }
    if (state == AppLifecycleState.resumed && _isMusicEnabled) {
      if (_pausedByLifecycle) {
        _pausedByLifecycle = false;
      }
      if (kDebugMode) debugPrint('[MUSIC] resumed — resuming music');
      unawaited(ensureMusicPlaying(forceRestart: false));
      return;
    }
    if (state == AppLifecycleState.detached) {
      _pausedByLifecycle = false;
      unawaited(stopMusic());
    }
  }

  Future<void> duckMusic({double factor = 0.10}) async {
    await init();
    if (!_isMusicEnabled) return;
    _duckFactor = factor.clamp(0.0, 1.0);
    _duckDepth++;
    await _applyMusicVolume();
  }

  Future<void> restoreMusic() async {
    if (_duckDepth > 0) {
      _duckDepth--;
    }
    if (!_isMusicEnabled) return;
    await _applyMusicVolume();
    if (_playerState != PlayerState.playing) {
      unawaited(ensureMusicPlaying());
    }
  }

  Future<void> setMusicEnabled(bool enabled) async {
    await init();
    if (kDebugMode) {
      debugPrint('[MUSIC] toggle → musicEnabled=$enabled');
    }
    _isMusicEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('musicEnabled', enabled);
    if (enabled) {
      _duckDepth = 0;
      await ensureMusicPlaying(forceRestart: true);
    } else {
      _duckDepth = 0;
      await stopMusic();
    }
  }

  Future<void> setMusicVolume(double volume) async {
    await init();
    _musicVolume = volume.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('musicVolume', _musicVolume);
    await _applyMusicVolume();
    if (_isMusicEnabled && _playerState == PlayerState.stopped) {
      unawaited(ensureMusicPlaying());
    }
  }

  void dispose() {
    if (_observerAttached) {
      WidgetsBinding.instance.removeObserver(this);
      _observerAttached = false;
    }
    _playerStateSub?.cancel();
    _bgmPlayer.dispose();
  }
}

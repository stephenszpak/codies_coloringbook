import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

enum SpeechPermissionState {
  undetermined,
  granted,
  denied,
  permanentlyDenied,
  unavailable,
}

enum SpeechListeningState {
  idle,
  listening,
  processing,
  error,
}

class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _lastResult = '';
  ValueNotifier<SpeechListeningState> listeningState = ValueNotifier(SpeechListeningState.idle);
  
  // Callbacks
  Function(String)? onResult;
  Function(String)? onError;
  Function()? onComplete;

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  String get lastResult => _lastResult;

  /// Check if speech recognition is available on this device
  Future<bool> get isSpeechAvailable async {
    try {
      if (!_isInitialized) {
        print('Initializing speech service...');
        _isInitialized = await _speechToText.initialize(
          onStatus: _onStatus,
          onError: _onError,
        );
        print('Speech service initialized: $_isInitialized');
      }
      return _isInitialized;
    } catch (e) {
      print('Error initializing speech service: $e');
      return false;
    }
  }

  /// Get the current device locale, fallback to en_US
  String get currentLocaleId {
    try {
      // Use device locale as fallback
      final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
      return '${deviceLocale.languageCode}_${deviceLocale.countryCode ?? 'US'}';
    } catch (e) {
      return 'en_US';
    }
  }

  /// Check microphone and speech permissions
  Future<SpeechPermissionState> checkMicAndSpeechPermissions() async {
    try {
      // First check if speech recognition is available
      if (!_isInitialized) {
        _isInitialized = await _speechToText.initialize(
          onStatus: _onStatus,
          onError: _onError,
        );
      }
      
      if (!_isInitialized) {
        print('Speech service not initialized');
        return SpeechPermissionState.unavailable;
      }

      // On iOS, the speech_to_text plugin handles both microphone and speech recognition permissions
      // We should rely on it rather than permission_handler for microphone permissions
      final hasSpeechPermission = await _speechToText.hasPermission;
      print('Speech recognition permission (includes microphone): $hasSpeechPermission');
      
      // Also check permission_handler for completeness, but don't rely on it as primary source
      final micStatus = await Permission.microphone.status;
      print('Permission_handler microphone status (may be inaccurate on iOS): $micStatus');
      
      if (hasSpeechPermission) {
        print('Speech permissions granted (microphone included)');
        return SpeechPermissionState.granted;
      } else {
        // Speech recognition permission not available - may need to request
        print('Speech recognition permission not available - may need to request');
        return SpeechPermissionState.undetermined;
      }
    } catch (e) {
      print('Error checking permissions: $e');
      return SpeechPermissionState.unavailable;
    }
  }

  /// Request microphone and speech permissions
  Future<SpeechPermissionState> requestMicAndSpeechPermissions() async {
    try {
      // First ensure speech recognition is initialized
      if (!_isInitialized) {
        _isInitialized = await _speechToText.initialize(
          onStatus: _onStatus,
          onError: _onError,
        );
      }
      
      if (!_isInitialized) {
        print('Cannot initialize speech service');
        return SpeechPermissionState.unavailable;
      }

      // On iOS, the speech_to_text plugin handles both permissions internally
      // Try to trigger the permission dialog by attempting to start listening
      print('Attempting to request speech recognition permissions (includes microphone)...');
      
      try {
        // This will trigger both microphone and speech recognition permission dialogs on iOS
        final canListen = await _speechToText.listen(
          onResult: (result) {}, 
          listenFor: const Duration(milliseconds: 100),
        );
        
        // Stop immediately
        await _speechToText.stop();
        
        if (canListen) {
          // Check permission after the dialogs
          final hasPermission = await _speechToText.hasPermission;
          print('Speech recognition permission after request: $hasPermission');
          
          if (hasPermission) {
            print('All permissions granted successfully');
            return SpeechPermissionState.granted;
          }
        }
        
        print('Permissions were denied');
        return SpeechPermissionState.permanentlyDenied;
        
      } catch (e) {
        print('Error requesting speech permissions: $e');
        
        // Check if permissions are actually available despite the error
        final hasPermission = await _speechToText.hasPermission;
        if (hasPermission) {
          print('Permissions available despite error');
          return SpeechPermissionState.granted;
        }
        
        return SpeechPermissionState.permanentlyDenied;
      }
    } catch (e) {
      print('Error requesting permissions: $e');
      return SpeechPermissionState.unavailable;
    }
  }

  /// Start listening for speech with auto-stop configuration
  /// Note: Permission checking should be done before calling this method
  Future<bool> startListening({
    Function(String)? onResult,
    Function(String)? onError,
    Function()? onComplete,
    Duration pauseFor = const Duration(seconds: 3),
    Duration listenFor = const Duration(seconds: 15),
  }) async {
    if (_isListening) return false;

    // Set callbacks
    this.onResult = onResult;
    this.onError = onError;
    this.onComplete = onComplete;

    try {
      // Initialize if needed
      if (!_isInitialized) {
        _isInitialized = await _speechToText.initialize(
          onStatus: _onStatus,
          onError: _onError,
        );
      }

      if (!_isInitialized) {
        _handleError('Speech recognition not available');
        return false;
      }

      // Start listening
      listeningState.value = SpeechListeningState.listening;
      _lastResult = '';
      
      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: listenFor,
        partialResults: true,
        localeId: currentLocaleId,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      );

      _isListening = true;
      return true;
    } catch (e) {
      _handleError('Failed to start listening: ${e.toString()}');
      return false;
    }
  }

  /// Stop listening manually
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speechToText.stop();
      _isListening = false;
      listeningState.value = SpeechListeningState.processing;
      
      // Brief delay to show processing state
      await Future.delayed(const Duration(milliseconds: 500));
      
      _completeListening();
    } catch (e) {
      _handleError('Failed to stop listening: ${e.toString()}');
    }
  }

  /// Cancel listening without processing result
  Future<void> cancelListening() async {
    if (!_isListening) return;

    try {
      await _speechToText.cancel();
      _isListening = false;
      _lastResult = '';
      listeningState.value = SpeechListeningState.idle;
    } catch (e) {
      _handleError('Failed to cancel listening: ${e.toString()}');
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    _lastResult = result.recognizedWords.trim();
    
    // No automatic timeout - user must manually stop
    // Call result callback with partial results
    onResult?.call(_lastResult);
    
    // If this is the final result (user stopped manually), complete listening
    if (result.finalResult) {
      _completeListening();
    }
  }

  void _onStatus(String status) {
    if (status == 'listening') {
      _isListening = true;
      listeningState.value = SpeechListeningState.listening;
    } else if (status == 'notListening') {
      _isListening = false;
      if (listeningState.value == SpeechListeningState.listening) {
        listeningState.value = SpeechListeningState.processing;
        // Brief delay then complete
        Timer(const Duration(milliseconds: 500), _completeListening);
      }
    }
  }

  void _onError(dynamic error) {
    _handleError('Speech recognition error: ${error.toString()}');
  }

  void _handleError(String errorMessage) {
    _isListening = false;
    listeningState.value = SpeechListeningState.error;
    onError?.call(errorMessage);
    
    // Return to idle after showing error briefly
    Timer(const Duration(seconds: 2), () {
      listeningState.value = SpeechListeningState.idle;
    });
  }

  void _completeListening() {
    _isListening = false;
    listeningState.value = SpeechListeningState.idle;
    onComplete?.call();
  }

  /// Dispose resources
  void dispose() {
    listeningState.dispose();
  }
}
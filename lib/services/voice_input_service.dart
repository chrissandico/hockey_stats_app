import 'package:speech_to_text/speech_to_text.dart';

/// Thin wrapper over the on-device speech recognizer (Android
/// SpeechRecognizer via the speech_to_text plugin). Recognition happens on
/// the device — no audio leaves the phone and no connectivity is required,
/// which rink use demands.
///
/// This service only captures a transcript. Turning a transcript into an
/// event is the parser's job, and logging it is the keeper's decision on the
/// verify card — nothing here writes data.
class VoiceInputService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  bool _listening = false;

  /// The current listening-state listener. Stored rather than captured by
  /// the one initialize() call, because the screen now pre-initializes in
  /// the background (no listener) and registers its listener on the first
  /// mic tap: the earlier shape made that later registration a no-op, so
  /// the button state desynced from the recognizer whenever the engine
  /// stopped on its own (timeout, error, interruption).
  void Function(bool isListening)? _onListeningChanged;

  bool get isListening => _listening;

  /// Initializes the recognizer (requests microphone permission on first
  /// use). Returns false when speech recognition is unavailable on this
  /// device or permission was denied. Safe to call repeatedly: a later
  /// call with a listener (re)registers it even when already initialized.
  Future<bool> ensureInitialized({
    void Function(bool isListening)? onListeningChanged,
  }) async {
    if (onListeningChanged != null) {
      _onListeningChanged = onListeningChanged;
    }
    if (_initialized) return true;
    try {
      _initialized = await _speech.initialize(
        onStatus: (status) {
          final listening = status == 'listening';
          if (listening != _listening) {
            _listening = listening;
            _onListeningChanged?.call(listening);
          }
        },
        onError: (error) {
          if (_listening) {
            _listening = false;
            _onListeningChanged?.call(false);
          }
          // ignore: avoid_print
          print('VoiceInputService error: ${error.errorMsg}');
        },
      );
    } catch (e) {
      // ignore: avoid_print
      print('VoiceInputService initialize failed: $e');
      _initialized = false;
    }
    return _initialized;
  }

  /// Starts a single listen window. [onTranscript] fires with partial
  /// results as the keeper speaks and once more with the final transcript
  /// (isFinal = true).
  ///
  /// ListenMode.confirmation suits short commands. [pauseFor] is 2s: the
  /// perf change's 1.2s finalized mid-command pauses ("Penalty 12 …
  /// tripping … 2 minutes") at the rink, while the original 3s made every
  /// command feel slow — 2s is the middle that holds both.
  Future<void> startListening({
    required void Function(String transcript, bool isFinal) onTranscript,
    Duration listenFor = const Duration(seconds: 8),
    Duration pauseFor = const Duration(seconds: 2),
    ListenMode listenMode = ListenMode.confirmation,
  }) async {
    if (!_initialized || _listening) return;
    _listening = true;
    await _speech.listen(
      onResult: (result) {
        onTranscript(result.recognizedWords, result.finalResult);
      },
      listenFor: listenFor,
      pauseFor: pauseFor,
      partialResults: true,
      listenMode: listenMode,
      cancelOnError: true,
    );
  }

  Future<void> stopListening() async {
    if (_listening) {
      _listening = false;
      await _speech.stop();
    }
  }

  Future<void> cancel() async {
    _listening = false;
    await _speech.cancel();
  }
}

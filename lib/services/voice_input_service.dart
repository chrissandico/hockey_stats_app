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

  bool get isListening => _listening;

  /// Initializes the recognizer (requests microphone permission on first
  /// use). Returns false when speech recognition is unavailable on this
  /// device or permission was denied.
  Future<bool> ensureInitialized({
    void Function(bool isListening)? onListeningChanged,
  }) async {
    if (_initialized) return true;
    try {
      _initialized = await _speech.initialize(
        onStatus: (status) {
          final listening = status == 'listening';
          if (listening != _listening) {
            _listening = listening;
            onListeningChanged?.call(listening);
          }
        },
        onError: (error) {
          if (_listening) {
            _listening = false;
            onListeningChanged?.call(false);
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
  /// (isFinal = true), which is the one callers should act on.
  Future<void> startListening({
    required void Function(String transcript, bool isFinal) onTranscript,
  }) async {
    if (!_initialized || _listening) return;
    _listening = true;
    await _speech.listen(
      onResult: (result) {
        onTranscript(result.recognizedWords, result.finalResult);
      },
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      listenMode: ListenMode.dictation,
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

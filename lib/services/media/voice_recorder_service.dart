import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

/// Recording state
enum RecordingState {
  idle,
  recording,
  paused,
  stopped,
}

/// Voice recorder service for recording audio messages
class VoiceRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  final Uuid _uuid = const Uuid();

  String? _currentPath;
  RecordingState _state = RecordingState.idle;
  DateTime? _startTime;

  RecordingState get state => _state;
  String? get currentPath => _currentPath;

  /// Get recording duration
  Duration get duration {
    if (_startTime == null) return Duration.zero;
    return DateTime.now().difference(_startTime!);
  }

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Start recording
  Future<bool> startRecording() async {
    try {
      // Check permission
      if (!await hasPermission()) {
        debugPrint('Microphone permission not granted');
        return false;
      }

      // Get temp directory
      final directory = await getTemporaryDirectory();
      final fileName = 'voice_${_uuid.v4()}.m4a';
      _currentPath = '${directory.path}/$fileName';

      // Configure recording
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
        numChannels: 1,
      );

      // Start recording
      await _recorder.start(config, path: _currentPath!);
      _state = RecordingState.recording;
      _startTime = DateTime.now();

      return true;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      _state = RecordingState.idle;
      return false;
    }
  }

  /// Pause recording
  Future<void> pauseRecording() async {
    if (_state != RecordingState.recording) return;

    try {
      await _recorder.pause();
      _state = RecordingState.paused;
    } catch (e) {
      debugPrint('Error pausing recording: $e');
    }
  }

  /// Resume recording
  Future<void> resumeRecording() async {
    if (_state != RecordingState.paused) return;

    try {
      await _recorder.resume();
      _state = RecordingState.recording;
    } catch (e) {
      debugPrint('Error resuming recording: $e');
    }
  }

  /// Stop recording and return the file path
  Future<String?> stopRecording() async {
    if (_state == RecordingState.idle) return null;

    try {
      final path = await _recorder.stop();
      _state = RecordingState.stopped;
      _startTime = null;
      return path;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      _state = RecordingState.idle;
      return null;
    }
  }

  /// Cancel recording and delete the file
  Future<void> cancelRecording() async {
    try {
      await _recorder.stop();

      // Delete the temp file
      if (_currentPath != null) {
        final file = File(_currentPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      _state = RecordingState.idle;
      _currentPath = null;
      _startTime = null;
    } catch (e) {
      debugPrint('Error canceling recording: $e');
    }
  }

  /// Get amplitude (for waveform visualization)
  Future<Amplitude> getAmplitude() async {
    return await _recorder.getAmplitude();
  }

  /// Check if recording is available
  Future<bool> isRecordingAvailable() async {
    return await _recorder.hasPermission();
  }

  /// Dispose the recorder
  Future<void> dispose() async {
    await _recorder.dispose();
  }
}

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

class AudioSynthesizer {
  /// Generate valid, playable PCM WAV audio bytes for voice notes in RAM
  static String generateVoiceNoteWav({
    required int durationSeconds,
    double baseFreq = 440.0,
  }) {
    const int sampleRate = 22050;
    const int numChannels = 1;
    const int bitsPerSample = 16;
    final int numSamples = sampleRate * durationSeconds;
    const int byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    const int blockAlign = numChannels * (bitsPerSample ~/ 8);
    final int dataSize = numSamples * (bitsPerSample ~/ 8);
    final int fileSize = 36 + dataSize;

    final bytes = BytesBuilder();

    // 1. RIFF Header
    bytes.add(utf8.encode('RIFF'));
    bytes.add(_int32ToBytes(fileSize));
    bytes.add(utf8.encode('WAVE'));

    // 2. fmt Sub-chunk
    bytes.add(utf8.encode('fmt '));
    bytes.add(_int32ToBytes(16));
    bytes.add(_int16ToBytes(1)); // PCM
    bytes.add(_int16ToBytes(numChannels));
    bytes.add(_int32ToBytes(sampleRate));
    bytes.add(_int32ToBytes(byteRate));
    bytes.add(_int16ToBytes(blockAlign));
    bytes.add(_int16ToBytes(bitsPerSample));

    // 3. data Sub-chunk
    bytes.add(utf8.encode('data'));
    bytes.add(_int32ToBytes(dataSize));

    // 4. Synthesize clear vocal waveform
    final rand = Random();
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final fundamental = sin(2 * pi * baseFreq * t);
      final harmonic1 = 0.5 * sin(2 * pi * (baseFreq * 2) * t);
      final harmonic2 = 0.25 * sin(2 * pi * (baseFreq * 3) * t);
      final modulation = 0.5 + 0.5 * sin(2 * pi * 4 * t);
      final noise = (rand.nextDouble() - 0.5) * 0.04;

      final wave = (fundamental + harmonic1 + harmonic2 + noise) * modulation;
      final sampleVal = (wave * 0.7 * 32767).toInt().clamp(-32768, 32767);
      bytes.add(_int16ToBytes(sampleVal));
    }

    final uint8List = bytes.toBytes();
    return base64Encode(uint8List);
  }

  static Uint8List _int16ToBytes(int value) {
    final b = ByteData(2)..setInt16(0, value, Endian.little);
    return b.buffer.asUint8List();
  }

  static Uint8List _int32ToBytes(int value) {
    final b = ByteData(4)..setInt32(0, value, Endian.little);
    return b.buffer.asUint8List();
  }
}

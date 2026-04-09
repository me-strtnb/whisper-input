import AVFoundation
import CoreAudio
import Foundation

class AudioRecorder {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var isRecording = false
    private var currentOutputURL: URL?
    var preferredDeviceID: AudioDeviceID?
    var onAudioLevel: ((Float) -> Void)?

    func startRecording(to outputURL: URL) throws {
        guard !isRecording else { return }

        let engine = AVAudioEngine()

        if let deviceID = preferredDeviceID {
            setInputDevice(deviceID, on: engine)
        }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        audioFile = try AVAudioFile(forWriting: outputURL, settings: settings)
        currentOutputURL = outputURL

        let converter = AVAudioConverter(from: format, to: recordingFormat)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self = self, let converter = converter else { return }

            let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: recordingFormat,
                frameCapacity: AVAudioFrameCount(
                    Double(buffer.frameLength) * 16000.0 / format.sampleRate
                )
            )!

            var error: NSError?
            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            if error == nil && convertedBuffer.frameLength > 0 {
                try? self.audioFile?.write(from: convertedBuffer)

                // Calculate RMS level for visualization
                if let channelData = buffer.floatChannelData?[0] {
                    let count = Int(buffer.frameLength)
                    var sumOfSquares: Float = 0
                    for i in 0..<count {
                        let sample = channelData[i]
                        sumOfSquares += sample * sample
                    }
                    let rms = sqrt(sumOfSquares / Float(max(count, 1)))
                    // Normalize: typical speech RMS is 0.01-0.1
                    let level = min(1.0, rms * 10.0)
                    self.onAudioLevel?(level)
                }
            }
        }

        engine.prepare()
        try engine.start()

        audioEngine = engine
        isRecording = true
    }

    func stopRecording() -> URL? {
        guard isRecording else { return nil }

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil
        isRecording = false

        return currentOutputURL
    }

    private func setInputDevice(_ deviceID: AudioDeviceID, on engine: AVAudioEngine) {
        guard let audioUnit = engine.inputNode.audioUnit else {
            print("Warning: could not access audio unit to set input device")
            return
        }

        var devID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &devID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        if status != noErr {
            print("Warning: failed to set audio input device (status: \(status))")
        }
    }
}

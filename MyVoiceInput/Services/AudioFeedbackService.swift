import AVFoundation

final class AudioFeedbackService {
    static let shared = AudioFeedbackService()
    
    private var startSoundPlayer: AVAudioPlayer?
    private var stopSoundPlayer: AVAudioPlayer?
    private var errorSoundPlayer: AVAudioPlayer?
    
    private init() {
        setupPlayers()
    }
    
    private func setupPlayers() {
        startSoundPlayer = createPlayer(for: "start-recording.mp3")
        stopSoundPlayer = createPlayer(for: "stop-recording.mp3")
        errorSoundPlayer = createPlayer(for: "error.mp3")
    }
    
    private func createPlayer(for filename: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: filename.replacingOccurrences(of: ".mp3", with: ""), withExtension: "mp3") else {
            print("AudioFeedbackService: Failed to find \(filename)")
            return nil
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            print("AudioFeedbackService: Failed to create player for \(filename): \(error)")
            return nil
        }
    }
    
    func playStartSound() {
        playSound(startSoundPlayer)
    }
    
    func playStopSound() {
        playSound(stopSoundPlayer)
    }
    
    func playErrorSound() {
        playSound(errorSoundPlayer)
    }
    
    private func playSound(_ player: AVAudioPlayer?) {
        guard let player = player else { return }
        player.currentTime = 0
        player.play()
    }
}

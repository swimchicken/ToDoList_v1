import Foundation
import AVFoundation
import MediaPlayer

class AlarmAudioManager: ObservableObject {
    static let shared = AlarmAudioManager()

    private var audioPlayer: AVAudioPlayer?
    private var isPlaying: Bool = false

    private init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            // 設置音頻會話為播放模式，確保能覆蓋靜音模式
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ 音頻會話設置成功")
        } catch {
            print("❌ 音頻會話設置失敗: \(error)")
        }
    }

    func playAlarmSound() {
        guard !isPlaying else {
            print("⚠️ 鬧鐘聲音已在播放中")
            return
        }

        // 優先使用 MP3 格式
        guard let soundURL = Bundle.main.url(forResource: "alarm_sound", withExtension: "mp3") else {
            print("❌ 找不到鬧鐘音頻文件")
            return
        }

        do {
            // 創建音頻播放器
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.numberOfLoops = -1 // 無限循環播放
            audioPlayer?.volume = 1.0 // 最大音量

            // 設置系統音量到最大
            setSystemVolume(to: 1.0)

            // 開始播放
            if audioPlayer?.play() == true {
                isPlaying = true
                print("🔊 鬧鐘聲音開始播放")

                // 設置鎖屏媒體信息
                setupNowPlayingInfo()
            } else {
                print("❌ 鬧鐘聲音播放失敗")
            }

        } catch {
            print("❌ 創建音頻播放器失敗: \(error)")
        }
    }

    func stopAlarmSound() {
        guard isPlaying else {
            print("⚠️ 鬧鐘聲音未在播放")
            return
        }

        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false

        // 清除鎖屏媒體信息
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

        print("🔇 鬧鐘聲音已停止")
    }

    private func setSystemVolume(to volume: Float) {
        // 設置系統音量
        let volumeView = MPVolumeView()
        if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                slider.value = volume
            }
        }
    }

    private func setupNowPlayingInfo() {
        // 設置鎖屏顯示信息
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = "鬧鐘"
        nowPlayingInfo[MPMediaItemPropertyArtist] = "ToDoList"
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = 999999 // 長時間播放
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    var isAlarmPlaying: Bool {
        return isPlaying
    }
}
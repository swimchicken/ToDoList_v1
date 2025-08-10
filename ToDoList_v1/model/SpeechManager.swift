import Foundation
import Speech
import AVFoundation

/// 一個管理語音辨識所有邏輯的類別
/// 這個類別遵循 ObservableObject 協議，使其可以在 SwiftUI 視圖中被監聽。
class SpeechManager: ObservableObject {
    // MARK: - Properties
    
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "zh-TW"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // 用來儲存從 View 傳入，並等待被呼叫的回調
    private var pendingCompletion: ((String) -> Void)?

    @Published var isRecording = false
    @Published var audioLevel: Double = 0.0

    // MARK: - Public Methods

    /// 請求麥克風和語音辨識的權限。
    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                if authStatus != .authorized {
                    print("語音辨識權限未被授予")
                }
            }
        }
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if !granted {
                    print("麥克風權限未被授予")
                }
            }
        }
    }

    /// 開始錄音和即時辨識。
    func start() {
        guard !isRecording else { return }
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("語音辨識器不可用")
            return
        }

        do {
            // 1. 設定音訊會話
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // 2. 準備辨識請求
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                fatalError("無法建立 SFSpeechAudioBufferRecognitionRequest 物件")
            }
            recognitionRequest.shouldReportPartialResults = false // 我們只在結束時需要最終結果

            let inputNode = audioEngine.inputNode
            
            // 3. 建立辨識任務，並定義好 resultHandler
            recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] (result, error) in
                guard let self = self else { return }
                let isFinal = result?.isFinal ?? false
                
                if isFinal || error != nil {
                    let finalText = result?.bestTranscription.formattedString ?? ""
                    self.cleanupAndComplete(with: finalText, error: error)
                }
            }

            // 4. 取得輸入節點的音訊格式，並安裝監聽器
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            // 確保有音訊格式可用，否則模擬器可能會崩潰
            guard recordingFormat.sampleRate > 0 else {
                print("錯誤：無法取得有效的音訊格式。請檢查模擬器或實體設備的麥克風設定。")
                self.cancel()
                return
            }
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
                
                let level = self?.calculateAudioLevel(buffer: buffer) ?? 0
                DispatchQueue.main.async {
                    self?.audioLevel = level
                }
            }

            // 5. 準備並啟動音訊引擎
            audioEngine.prepare()
            try audioEngine.start()
            
            // 6. 更新狀態
            isRecording = true
            
        } catch {
            print("Audio engine 或辨識任務無法啟動: \(error.localizedDescription)")
            self.cancel()
        }
    }

    /// 停止錄音和辨識，並透過 completion 回傳最終結果。
    func stop(completion: @escaping (String) -> Void) {
        guard audioEngine.isRunning else {
            completion("")
            return
        }
        
        self.pendingCompletion = completion
        recognitionRequest?.endAudio()
    }
    
    /// 取消錄音，不處理任何結果。
    func cancel() {
        cleanupAndComplete(with: "", error: nil, shouldCancelTask: true)
    }
    
    // MARK: - Private Helper Methods
    
    /// 統一處理清理和回調的函式
    private func cleanupAndComplete(with text: String, error: Error?, shouldCancelTask: Bool = false) {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        if shouldCancelTask {
            recognitionTask?.cancel()
        }
        
        if let error = error {
            let nsError = error as NSError
            if !(nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216) {
                print("語音辨識錯誤: \(error.localizedDescription)")
            }
        }
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.audioLevel = 0.0
            
            if let completion = self.pendingCompletion {
                completion(text)
            }
            
            self.recognitionRequest = nil
            self.recognitionTask = nil
            self.pendingCompletion = nil
        }
    }
    
    private func calculateAudioLevel(buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride).map{ channelDataValue[$0] }
        let rms = sqrt(channelDataValueArray.map{ $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let avgPower = 20 * log10(rms)
        let normalizedPower = Double(max(0, avgPower + 50) / 50)
        return min(normalizedPower, 1.0)
    }
}

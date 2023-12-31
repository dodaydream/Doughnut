//
//  TranscriptViewController.swift
//  Doughnut
//
//  Created by Stanley Cao on 2023-12-29.
//  Copyright © 2023 Chris Dyer. All rights reserved.
//

import Foundation
import AVFoundation
import SwiftWhisper
import AudioKit

class TranscriptViewController: NSViewController, TranscriptDelegate {
    
    
    @IBOutlet weak var lyricsView: LyricsScrollView!
    
    private let player = Player.global
    
    private var isActive = false
    
    public func setIsActive(_ active: Bool) {
        isActive = active
    }
    
    func convertAudioFileToPCMArray(fileURL: URL, completionHandler: @escaping (Result<[Float], Error>) -> Void) {
        
        lyricsView.reset()
        
        print("attempt converting file to PCM array")
        
        var options = FormatConverter.Options()
        options.format = .wav
        options.sampleRate = 16000
        options.bitDepth = 16
        options.channels = 1
        options.isInterleaved = false

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let converter = FormatConverter(inputURL: fileURL, outputURL: tempURL, options: options)
        converter.start { error in
            if let error {
                completionHandler(.failure(error))
                return
            }

            do {
                let data = try Data(contentsOf: tempURL) // Handle error here
                
                let floats = stride(from: 44, to: data.count, by: 2).map {
                    return data[$0..<$0 + 2].withUnsafeBytes {
                        let short = Int16(littleEndian: $0.load(as: Int16.self))
                        return max(-1.0, min(Float(short) / 32767.0, 1.0))
                    }
                }
                
                try? FileManager.default.removeItem(at: tempURL)
                
                completionHandler(.success(floats))
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
    
    func convertTranscript(_ floats: [Float], completionHandler: @escaping (Result<[Segment], Error>) -> Void) {
        // path: /users/stanley/models/base.bin
        let modelURL = URL(fileURLWithPath: "/users/stanley/models/ggml-base.bin")
        let whisper = Whisper(fromFileURL: modelURL)
        whisper.transcribe(audioFrames: floats/* 16kHz PCM audio frames */) { segments in
            completionHandler(segments)
        }
    }
    
    func onAssetsLoaded(url: URL) {
        
        print("start downloading file from \(url.absoluteString)")
        // download the file
        let task = URLSession.shared.downloadTask(with: url) { (tempLocalURL, response, error) in
            if let tempLocalURL = tempLocalURL, error == nil {
                
                print("downloaded to \(tempLocalURL.absoluteString)")
                
                do {
                    self.convertAudioFileToPCMArray(fileURL: tempLocalURL) { result in
                        switch result {
                        case .success(let floats):
                            self.convertTranscript(floats) { result in
                                switch result {
                                case .success(let segments):
                                    DispatchQueue.main.async {
                                        // self.transcriptText.stringValue = segments.map(\.text).joined(separator: "\n")
                                        self.lyricsView.setupTextContents(segments: segments)
                                        print(segments.map({ "[\($0.startTime)][\($0.endTime)] \($0.text)"}).joined(separator: "\n"))
                                    }
                                case .failure(let error):
                                    print(error)
                                }
                            }
                        case .failure(let error):
                            print(error)
                        }
                    }
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
        
        task.resume()
    }
    
    override func viewDidLoad() {
        player.transcriptDelegate = self
    }
    
//    override func viewDidAppear() {
//        print("view did appear")
//    }
//    
//    override func viewDidDisappear() {
//        print("view did disappear")
//        removePeriodicTimeObserver()
//    }
}

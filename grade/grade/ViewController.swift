//
//  ViewController.swift
//  grade
//
//  Created by Gayathri on 06/11/24.
//

import UIKit
import AVFoundation
import AVKit

class ViewController: UIViewController {
    
    
    @IBOutlet weak var videoPlayer: UIView!
    
    
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var redSlider: UISlider!
    
    @IBOutlet weak var redLabel: UILabel!
    @IBOutlet weak var greenSlider: UISlider!
    
    @IBOutlet weak var greenLabel: UILabel!
    
    @IBOutlet weak var blueLabel: UILabel!
    @IBOutlet weak var blueSlider: UISlider!
    
    @IBOutlet weak var alphaSlider: UISlider!
    
    
    @IBOutlet weak var alphaLabel: UILabel!
    
    
    
    
    @IBOutlet weak var resetButton: UIButton!
    private let defaultRedValue: Float = 1.0
      private let defaultGreenValue: Float = 1.0
      private let defaultBlueValue: Float = 1.0
      private let defaultAlphaValue: Float = 0.5
       private var player: AVPlayer?
       private var playerLayer: AVPlayerLayer?
       private var imageGenerator: AVAssetImageGenerator?
       private var displayLink: CADisplayLink?
       private var isGeneratingImage = false
       private var asset: AVAsset?
       
       override func viewDidLoad() {
           super.viewDidLoad()
           setupVideoPlayer()
           setupSliders()
           setupResetButton()
       }
       
       private func setupSliders() {
           alphaSlider.minimumValue = 0.1
           alphaSlider.value = 0.5
           redSlider.value = 1.0
           greenSlider.value = 1.0
           blueSlider.value = 1.0
       }
       
       private func setupVideoPlayer() {
           guard let videoURL = URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4") else {
               print("Invalid video URL")
               return
           }
           
           // Create asset and wait for it to be ready
           let asset = AVAsset(url: videoURL)
           self.asset = asset
           
           // Load the asset's tracks asynchronously
           Task {
               do {
                   // Ensure the asset is playable
                   let tracks = try await asset.loadTracks(withMediaType: .video)
                   guard !tracks.isEmpty else {
                       print("No video tracks found")
                       return
                   }
                   
                   // Setup player only after we confirm we have video tracks
                   await MainActor.run {
                       self.setupPlayerWithAsset(asset)
                       self.setupImageGenerator(asset)
                   }
               } catch {
                   print("Error loading video tracks: \(error.localizedDescription)")
               }
           }
       }
    private func setupResetButton() {
           // Configure reset button if needed
           resetButton.setTitle("Reset ", for: .normal)
           resetButton.addTarget(self, action: #selector(resetButtonTapped), for: .touchUpInside)
       }
       
       @objc private func resetButtonTapped() {
           resetSlidersToDefault()
           
           // Update the current frame with reset values
           if let currentTime = player?.currentTime() {
               updateImageForTime(currentTime)
           }
       }
       
       private func resetSlidersToDefault() {
           // Reset all sliders to their default values
           redSlider.value = defaultRedValue
           greenSlider.value = defaultGreenValue
           blueSlider.value = defaultBlueValue
           alphaSlider.value = defaultAlphaValue
           
           // Update labels if needed
           redLabel.text = String(format: "Red: %.2f", defaultRedValue)
           greenLabel.text = String(format: "Green: %.2f", defaultGreenValue)
           blueLabel.text = String(format: "Blue: %.2f", defaultBlueValue)
           alphaLabel.text = String(format: "Alpha: %.2f", defaultAlphaValue)
       }
       
       
       private func setupPlayerWithAsset(_ asset: AVAsset) {
           let playerItem = AVPlayerItem(asset: asset)
           player = AVPlayer(playerItem: playerItem)
           
           playerLayer = AVPlayerLayer(player: player)
           playerLayer?.frame = videoPlayer.bounds
           playerLayer?.videoGravity = .resizeAspect
           videoPlayer.layer.addSublayer(playerLayer!)
           
           // Add iOS controls
           let controller = AVPlayerViewController()
           controller.player = player
           addChild(controller)
           videoPlayer.addSubview(controller.view)
           controller.view.frame = videoPlayer.bounds
           controller.didMove(toParent: self)
           
           // Add observer for player status
           player?.currentItem?.addObserver(self,
                                          forKeyPath: "status",
                                          options: [.new, .old],
                                          context: nil)
           
           // Add periodic time observer
           let interval = CMTime(seconds: 1.0/30.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
           player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
               self?.updateImageForTime(time)
           }
           
           player?.play()
       }
       
       private func setupImageGenerator(_ asset: AVAsset) {
           imageGenerator = AVAssetImageGenerator(asset: asset)
           imageGenerator?.appliesPreferredTrackTransform = true
           imageGenerator?.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 30)
           imageGenerator?.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 30)
           imageGenerator?.maximumSize = CGSize(width: 1280, height: 720)
       }
       
       private func updateImageForTime(_ time: CMTime) {
           guard !isGeneratingImage,
                 let imageGenerator = imageGenerator,
                 let player = player,
                 player.currentItem?.status == .readyToPlay,
                 time.isValid else {
               return
           }
           
           guard let duration = player.currentItem?.duration,
                 CMTimeCompare(time, duration) < 0 else {
               return
           }
           
           isGeneratingImage = true
           
           Task {
               do {
                   let actualTime = CMTimeGetSeconds(time)
                   let requestedTime = CMTimeMakeWithSeconds(actualTime, preferredTimescale: time.timescale)
                   
                   let cgImage = try await imageGenerator.copyCGImage(at: requestedTime, actualTime: nil)
                   
                   await MainActor.run {
                       let originalImage = UIImage(cgImage: cgImage)
                       if let gradedImage = applyColorGrading(to: originalImage) {
                           self.imageView.image = gradedImage
                       }
                       self.isGeneratingImage = false
                   }
               } catch {
                   print("Error generating thumbnail: \(error)")
                   await MainActor.run {
                       self.isGeneratingImage = false
                   }
               }
           }
       }
       
    private func applyColorGrading(to image: UIImage) -> UIImage? {
        let redValue = CGFloat(redSlider.value)
        let greenValue = CGFloat(greenSlider.value)
        let blueValue = CGFloat(blueSlider.value)
        let alphaValue = CGFloat(max(alphaSlider.value, 0.1))

        // Begin an image context
        UIGraphicsBeginImageContextWithOptions(image.size, false, 1.0)
        defer {
            UIGraphicsEndImageContext()
        }

        guard let context = UIGraphicsGetCurrentContext(),
              let cgImage = image.cgImage else {
            return nil
        }

        // Flip the context vertically
        context.translateBy(x: 0, y: image.size.height)
        context.scaleBy(x: 1.0, y: -1.0)

        // Draw the original image
        let rect = CGRect(origin: .zero, size: image.size)
        context.draw(cgImage, in: rect)

        // Apply color overlay with adjusted RGB values
        context.setFillColor(red: redValue, green: greenValue, blue: blueValue, alpha: alphaValue)
        context.setBlendMode(.sourceAtop)
        context.fill(rect)

        // Capture the new graded image
        return UIGraphicsGetImageFromCurrentImageContext()
    }

       
       override func observeValue(forKeyPath keyPath: String?,
                                of object: Any?,
                                change: [NSKeyValueChangeKey : Any]?,
                                context: UnsafeMutableRawPointer?) {
           if keyPath == "status",
              let playerItem = object as? AVPlayerItem {
               switch playerItem.status {
               case .failed:
                   print("Player item failed: \(String(describing: playerItem.error))")
               case .readyToPlay:
                   print("Player item is ready to play")
               case .unknown:
                   print("Player item status is unknown")
               @unknown default:
                   break
               }
           }
       }
       
       override func viewDidLayoutSubviews() {
           super.viewDidLayoutSubviews()
           playerLayer?.frame = videoPlayer.bounds
       }
       
       deinit {
           displayLink?.invalidate()
           if let playerItem = player?.currentItem {
               playerItem.removeObserver(self, forKeyPath: "status")
           }
           player?.removeTimeObserver(self)
       }
   }

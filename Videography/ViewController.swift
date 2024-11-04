//
//  ViewController.swift
//  Videography
//
//  Created by Nauman Abrar on 04/11/2024.
//

//
//  ViewController.swift
//  Videography
//
//  Created by Nauman Abrar on 04/11/2024.
//

import UIKit
import AVFoundation
import AVKit
import PhotosUI
import CoreImage

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // MARK: - Outlets
    @IBOutlet weak var videoPreviewView: UIView!
    @IBOutlet weak var playBtn: UIButton!
    @IBOutlet weak var filterBtn: UIButton!
    @IBOutlet weak var uploadBtn: UIButton!
    
    // MARK: - Properties
    private var player: AVPlayer?
    private var videoURL: URL?
    private var playerLayer: AVPlayerLayer?
    private var isPlaying = false {
        didSet {
            playBtn.setImage(UIImage(systemName: isPlaying ? "pause.fill" : "play.fill"), for: .normal)
        }
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupInitialUI()
    }
    
    // MARK: - UI Setup
    private func setupInitialUI() {
        clearVideoPreview()
        playBtn.isHidden = true
        filterBtn.isHidden = true
    }
    
    private func clearVideoPreview() {
        videoPreviewView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
    }
    
    // MARK: - Actions
    @IBAction func pickVideoButtonTapped(_ sender: UIButton) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.mediaTypes = ["public.movie"]
        picker.allowsEditing = true
        present(picker, animated: true)
    }
    
    @IBAction func playBtnTap(_ sender: UIButton) {
        guard let player = player else {
            print("Player is not initialized")
            return
        }
        
        if isPlaying {
            player.pause()
            print("Video paused")
        } else {
            player.play()
            print("Video playing")
        }
        
        isPlaying.toggle()
    }
    
    @IBAction func applyFilterButtonTapped(_ sender: UIButton) {
        guard let videoURL = videoURL else { return }
        
        pauseVideo()
        let currentTime = player?.currentTime() ?? .zero
        
        let asset = AVAsset(url: videoURL)
        applyFilterToVideo(asset: asset, filterName: "CISepiaTone") { [weak self] playerItem in
            guard let self = self, let playerItem = playerItem else { return }
            
            self.player?.replaceCurrentItem(with: playerItem)
            DispatchQueue.main.async {
                self.updatePreviewLayer()
                self.player?.seek(to: currentTime) { _ in
                    self.playVideo()
                }
            }
        }
    }
    
    // MARK: - Video Handling
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        
        if let videoURL = info[.mediaURL] as? URL {
            self.videoURL = videoURL
            previewVideo(url: videoURL)
            playBtn.isHidden = false
            filterBtn.isHidden = false
        }
    }
    
    private func previewVideo(url: URL) {
        clearVideoPreview()
        
        player = AVPlayer(url: url)
        updatePreviewLayer()
        addVideoEndObserver()
        
        playVideo()
    }
    
    private func updatePreviewLayer() {
        playerLayer?.removeFromSuperlayer()
        
        guard let player = player else { return }
        
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = videoPreviewView.bounds
        playerLayer?.videoGravity = .resizeAspect
        videoPreviewView.layer.addSublayer(playerLayer!)
    }
    
    private func addVideoEndObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(videoDidEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem
        )
    }
    
    private func playVideo() {
        player?.play()
        isPlaying = true
    }
    
    private func pauseVideo() {
        player?.pause()
        isPlaying = false
    }
    
    @objc private func videoDidEnd(notification: Notification) {
        print("Video ended. Resetting to the beginning.")
        player?.seek(to: .zero)
        isPlaying = false
    }
    
    private func applyFilterToVideo(asset: AVAsset, filterName: String, completion: @escaping (AVPlayerItem?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Create the video composition
            let composition = AVVideoComposition(asset: asset) { request in
                let source = request.sourceImage.clampedToExtent()
                if let filter = CIFilter(name: filterName) {
                    filter.setValue(source, forKey: kCIInputImageKey)
                    if let output = filter.outputImage?.cropped(to: source.extent) {
                        request.finish(with: output, context: nil)
                        return
                    }
                }
                request.finish(with: source, context: nil)
            }

            // Create player item with the composition
            let playerItem = AVPlayerItem(asset: asset)
            playerItem.videoComposition = composition

            // Return to the main thread to complete the UI update
            DispatchQueue.main.async {
                completion(playerItem)
            }
        }
    }

}

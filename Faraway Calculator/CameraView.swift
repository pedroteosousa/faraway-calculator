//
//  CameraView.swift
//  Faraway Calculator
//
//  Created by Pedro Sousa on 08/11/24.
//

import SwiftUI
import UIKit
import Combine
import AVFoundation
import Vision

struct CameraView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CameraViewController {
        let cameraViewController = CameraViewController()
        return cameraViewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
}

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var bufferSize: CGSize = .zero
    
    var showPredictionText: Bool = false

    private var model: VNCoreMLModel! = nil
    
    private var previewLayer: AVCaptureVideoPreviewLayer! = nil
    private var previewLayerRect: CGRect! = nil
    
    private var captureConnection: AVCaptureConnection! = nil
    
    private var request: VNCoreMLRequest! = nil
    
    private var detectionOverlay: CALayer! = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, options: .mixWithOthers)
            try audioSession.setActive(false)
        }catch{
            // handle error
        }
        
        self.model = try? VNCoreMLModel(for: best().model)
        
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        captureSession.addInput(input)
        
        captureSession.startRunning()
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        previewLayer.frame = view.frame
        
        detectionOverlay = CALayer()
        detectionOverlay.bounds = previewLayer.bounds
        detectionOverlay.position = previewLayer.position
        view.layer.addSublayer(detectionOverlay)
        
        request = VNCoreMLRequest(model: self.model, completionHandler: {
            (request, err) in
            DispatchQueue.main.async(execute: {
                if let results = request.results {
                    var cards: [Detection] = []
                    for observation in results {
                        guard let object = observation as? VNRecognizedObjectObservation else { continue }
                        let objectBounds = VNImageRectForNormalizedRect(object.boundingBox, Int(self.bufferSize.width), Int(self.bufferSize.height))
                        let detection = Detection(
                            boundingBox: objectBounds,
                            identifier: object.labels[0].identifier,
                            confidence: object.labels[0].confidence)
                        if self.isInsidePreviewLayer(rect: objectBounds) {
                            cards.append(detection)
                        }
                    }
                    self.drawCardDetections(cards: cards)
                    GameStateUpdater.shared.newDetection(cards: cards)
                }
            })
        })
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(dataOutput)
        
        captureConnection = dataOutput.connection(with: .video)
        captureConnection?.isEnabled = true
        
        orientViews()
        
        do {
            try captureDevice.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions(captureDevice.activeFormat.formatDescription)
            bufferSize.width = CGFloat(dimensions.width)
            bufferSize.height = CGFloat(dimensions.height)
            captureDevice.unlockForConfiguration()
            previewLayerRect = calculatePreviewLayerRect()
        } catch {
            print(error)
        }
    }
    
    private func drawCardDetections(cards: [Detection]) {
        detectionOverlay.sublayers?.forEach({ $0.removeFromSuperlayer() })
        cards.forEach({
            let bounds = self.convertToDetectionLayerRect(rect: $0.boundingBox)
            let shape = CALayer()
            shape.bounds = bounds
            shape.position = CGPoint(x: bounds.midX, y: bounds.midY)
            shape.borderWidth = 5
            shape.borderColor = .init(red: 0.5, green: 0.0, blue: 0.5, alpha: 1.0)
            if showPredictionText {
                let textLayer = createTextSubLayerInBounds(bounds: bounds, identifier: $0.identifier, confidence: $0.confidence)
                shape.addSublayer(textLayer)
            }
            detectionOverlay.addSublayer(shape)
        })
    }
    
    func orientViews() {
        let orientation = UIDevice.current.orientation
        switch orientation {
        case .landscapeRight:
            self.previewLayer.connection?.videoRotationAngle = 180
            captureConnection?.videoRotationAngle = 180
        default:
            self.previewLayer.connection?.videoRotationAngle = 0
            captureConnection?.videoRotationAngle = 0
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        orientViews()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer).perform([request])
    }
    
    private func calculatePreviewLayerRect() -> CGRect {
        let previewImageLayerBounds = previewLayer.bounds
        
        let originalWidth = bufferSize.width
        let originalHeight = bufferSize.height
        
        let A = previewImageLayerBounds.origin
        let D = CGPoint(x: previewImageLayerBounds.size.width, y: previewImageLayerBounds.size.height)
        
        let a = previewLayer.captureDevicePointConverted(fromLayerPoint: A)
        let d = previewLayer.captureDevicePointConverted(fromLayerPoint: D)
        
        let posX = floor(a.x * originalWidth)
        let posY = floor(a.y * originalHeight)
        
        let width: CGFloat = d.x * originalWidth - a.x * originalWidth
        let height: CGFloat = d.y * originalHeight - a.y * originalHeight
        
        return CGRect(x: posX, y: posY, width: width, height: height)
    }
    
    private func createTextSubLayerInBounds(bounds: CGRect, identifier: String, confidence: VNConfidence) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.name = "Object Label"
        let formattedString = NSMutableAttributedString(string: String(format: "\(identifier)\nConfidence:\n%.2f", confidence))
        let largeFont = UIFont(name: "Helvetica", size: 24.0)!
        formattedString.addAttributes([NSAttributedString.Key.font: largeFont], range: NSRange(location: 0, length: identifier.count))
        textLayer.string = formattedString
        textLayer.bounds = CGRect(x: 0, y: 0, width: bounds.size.height - 10, height: bounds.size.width - 10)
        textLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        textLayer.shadowOpacity = 0.7
        textLayer.shadowOffset = CGSize(width: 2, height: 2)
        textLayer.foregroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.0, 0.0, 0.0, 1.0])
        textLayer.contentsScale = 2.0
        return textLayer
    }
    
    private func convertToDetectionLayerRect(rect: CGRect) -> CGRect {
        let originX = (rect.origin.x - previewLayerRect.origin.x) / previewLayerRect.width * detectionOverlay.bounds.width
        let originY = detectionOverlay.bounds.height - (rect.maxY - previewLayerRect.origin.y) / previewLayerRect.height * detectionOverlay.bounds.height
        let width = rect.width / previewLayerRect.width * detectionOverlay.bounds.width
        let height = rect.height / previewLayerRect.height * detectionOverlay.bounds.height
        
        return CGRect(x: originX, y: originY, width: width, height: height)
    }
    
    private func isInsidePreviewLayer(rect: CGRect) -> Bool {
        return previewLayerRect.contains(rect.origin) && previewLayerRect.contains(CGPoint(x: rect.origin.x + rect.width, y: rect.origin.y + rect.height))
    }
}

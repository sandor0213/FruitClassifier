//
//  ViewController.swift
//  FruitClassifier
//
// Created by Balogh Shandor

import UIKit
import Vision
import AVFoundation

final class ViewController: UIViewController {
    
    @IBOutlet weak var resultLabel: UILabel?
    
    let captureSession = AVCaptureSession()
    var captureDevice: AVCaptureDevice?
    var requests: [VNRequest] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupVision()
        prepareCamera()
    }
}

private extension ViewController {
    func showCameraCapture() {
        let cameraLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        cameraLayer.frame = view.frame
        cameraLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(cameraLayer, below: resultLabel?.layer)
    }
    
    func prepareCamera() {
        let availableDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices
        captureDevice = availableDevices.first
        beginSession()
        showCameraCapture()
    }
    
    func beginSession() {
        guard let captureDevice = captureDevice else { return }
        do {
            let captureDeviceInput = try AVCaptureDeviceInput(device: captureDevice)
            captureSession.addInput(captureDeviceInput)
        } catch {
            print("Could not create video device input")
            return
        }
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .vga640x480
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        dataOutput.alwaysDiscardsLateVideoFrames = true
        
        if captureSession.canAddOutput(dataOutput) {
            captureSession.addOutput(dataOutput)
        }
        
        captureSession.commitConfiguration()
        
        let queue = DispatchQueue(label: "captureQueue")
        dataOutput.setSampleBufferDelegate(self, queue: queue)
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    func setupVision() {
        guard let visionModel = try? VNCoreMLModel(for: FruitClassifierResourcesWithBananaAppleCarrotNoneCleaned().model) else { return }
        
        let classificationRequest = VNCoreMLRequest(model: visionModel, completionHandler: handleClassification)
        classificationRequest.imageCropAndScaleOption = .centerCrop
        
        requests = [classificationRequest]
    }
    
    func handleClassification(request: VNRequest, error: Error?) {
        guard let observations = request.results else { return }
        
        let classificationTuples = observations.compactMap({ $0 as? VNClassificationObservation }).map({ ($0.identifier, $0.confidence) })
        print(classificationTuples)
        DispatchQueue.main.async { [weak self] in
            self?.resultLabel?.text = "\(classificationTuples.first?.0 ?? ""), \((Int((classificationTuples.first?.1 ?? 0) * 100)))%"
        }
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        
        do {
            try imageRequestHandler.perform(requests)
        } catch {
            print(error)
        }
    }
}

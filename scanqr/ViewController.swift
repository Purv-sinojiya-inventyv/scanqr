import UIKit
import AVFoundation
import CoreImage
import Vision

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, AVCaptureMetadataOutputObjectsDelegate {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var selectImageButton: UIButton!
    @IBOutlet weak var scanQRCodeButton: UIButton!
    @IBOutlet weak var scanUsingVisionButton: UIButton! // Button for Vision detection

    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        selectImageButton.addTarget(self, action: #selector(selectImageTapped), for: .touchUpInside)
        scanQRCodeButton.addTarget(self, action: #selector(checkCameraPermissionAndStartScanning), for: .touchUpInside)
        scanUsingVisionButton.addTarget(self, action: #selector(selectImageForVisionDetection), for: .touchUpInside)
    }

    // MARK: - Camera Permission
    @objc func checkCameraPermissionAndStartScanning() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startScanning()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.startScanning()
                    } else {
                        self.showAlert(title: "Camera Access Denied", message: "Enable camera access in settings.")
                    }
                }
            }
        case .denied, .restricted:
            showAlert(title: "Camera Access Denied", message: "Enable camera access in settings.")
        @unknown default:
            break
        }
    }

    // MARK: - Setup Camera for Live Scanning
    func startScanning() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showAlert(title: "No Camera Found", message: "This device does not have a camera.")
            return
        }
        
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            showAlert(title: "Camera Unavailable", message: "No camera found on this device.")
            return
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            if captureSession?.canAddInput(videoInput) == true {
                captureSession?.addInput(videoInput)
            } else {
                showAlert(title: "Error", message: "Could not add camera input.")
                return
            }
        } catch {
            showAlert(title: "Camera Error", message: "Error accessing the camera: \(error.localizedDescription)")
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession?.canAddOutput(metadataOutput) == true {
            captureSession?.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            showAlert(title: "Error", message: "Could not add metadata output.")
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer?.frame = view.layer.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer!, at: 0)
        
        captureSession?.startRunning()
    }

    // MARK: - Live QR Code Detection
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              metadataObject.type == .qr,
              let qrCode = metadataObject.stringValue else {
            return
        }
        
        captureSession?.stopRunning()
        DispatchQueue.main.async {
            self.showAlert(title: "QR Code Scanned", message: qrCode)
        }
    }

    // MARK: - Select Image from Gallery
    @objc func selectImageTapped() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc func selectImageForVisionDetection() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        picker.view.tag = 1 // Vision Detection
        present(picker, animated: true)
    }

    // MARK: - Handle Image Selection
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        guard let selectedImage = info[.originalImage] as? UIImage else {
            print("❌ Error: No image found")
            return
        }
        
        imageView.image = selectedImage
        
        if picker.view.tag == 1 {
            detectQRCodeUsingVision(in: selectedImage) // Vision-based detection
        } else {
            detectQRCodeUsingCIDetector(in: selectedImage) // Core Image-based detection
        }
    }

    // MARK: - QR Code Detection Using CIDetector (Core Image)
    func detectQRCodeUsingCIDetector(in image: UIImage) {
        guard let ciImage = CIImage(image: image) else {
            print("❌ Error: Could not convert UIImage to CIImage")
            return
        }

        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])

        if let features = detector?.features(in: ciImage), let qrFeature = features.first as? CIQRCodeFeature {
            let qrCode = qrFeature.messageString ?? "No QR code found"
            print("✅ QR Code Found: \(qrCode)")
            DispatchQueue.main.async {
                self.showAlert(title: "QR Code Found", message: qrCode)
            }
        } else {
            DispatchQueue.main.async {
                self.showAlert(title: "No QR Code Found", message: "Try another image.")
            }
        }
    }

    // MARK: - Vision-Based QR Code Detection
    func detectQRCodeUsingVision(in image: UIImage) {
        guard let cgImage = image.cgImage else {
            print("❌ Error: Could not convert UIImage to CGImage")
            return
        }

        let request = VNDetectBarcodesRequest { request, error in
            guard error == nil else {
                print("❌ Vision Error: \(error!.localizedDescription)")
                return
            }
            
            if let results = request.results as? [VNBarcodeObservation], let firstResult = results.first {
                let qrCode = firstResult.payloadStringValue ?? "No QR Code detected"
                print("✅ Vision QR Code Found: \(qrCode)")
                DispatchQueue.main.async {
                    self.showAlert(title: "QR Code Found", message: qrCode)
                }
            } else {
                DispatchQueue.main.async {
                    self.showAlert(title: "No QR Code Found", message: "Try another image.")
                }
            }
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("❌ Vision Handler Error: \(error.localizedDescription)")
        }
    }

    // MARK: - Alert Helper
    func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
}

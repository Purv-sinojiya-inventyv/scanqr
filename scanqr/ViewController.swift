import UIKit
import CoreImage

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // MARK: - UI Elements
    @IBOutlet weak var selectImageButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var messageLabel: UILabel!
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("🚀 App Started - Ready to detect QR codes")
    }
    
    // MARK: - Open Photo Library
    @IBAction func selectImageTapped(_ sender: UIButton) {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker, animated: true)
    }
    
    // MARK: - Handle Selected Image
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        guard let selectedImage = info[.originalImage] as? UIImage else {
            print("❌ Error: No image found")
            return
        }
        
        imageView.image = selectedImage
        detectQRCodeInImage(selectedImage)
    }
    
    // MARK: - QR Code Detection using CoreImage
    func detectQRCodeInImage(_ image: UIImage) {
        guard let ciImage = CIImage(image: image) else {
            print("❌ Error: Unable to convert UIImage to CIImage")
            return
        }

        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let features = detector?.features(in: ciImage) as? [CIQRCodeFeature] ?? []
        
        if features.isEmpty {
            print("❌ No QR code found")
            DispatchQueue.main.async {
                self.messageLabel.text = "No QR code detected"
            }
            return
        }

        for feature in features {
            if let code = feature.messageString {
                print("✅ QR Code Found: \(code)")
                DispatchQueue.main.async {
                    self.messageLabel.text = "QR Code: \(code)"
                    self.showAlert(title: "QR Code Found", message: code)
                }
            }
        }
    }
    
    // MARK: - Show Alert
    func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
}

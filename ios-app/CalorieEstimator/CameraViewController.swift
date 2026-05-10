import UIKit
import AVFoundation
import Photos

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var delegate: ((UIImage) -> Void)?

    var overlayView: UIView!
    private var shouldCapture = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // Minta izin akses photo library dulu sebelum mulai kamera
        requestPhotoLibraryPermission()

        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high

        guard let backCamera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: backCamera),
              captureSession.canAddInput(input) else { return }
        captureSession.addInput(input)

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
        view.layer.addSublayer(previewLayer)

        // Tambah overlay kotak 1:1
        overlayView = UIView()
        overlayView.layer.borderColor = UIColor.white.cgColor
        overlayView.layer.borderWidth = 2
        view.addSubview(overlayView)

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        captureSession.startRunning()
    }

    func requestPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        print("Izin photo library granted")
                    } else {
                        print("Izin photo library ditolak atau terbatas")
                        self.showPermissionAlert()
                    }
                }
            }
        } else if status == .denied || status == .restricted {
            // Izin ditolak, kasih alert ke user agar buka Settings
            showPermissionAlert()
        }
    }

    func showPermissionAlert() {
        let alert = UIAlertController(
            title: "Izin Foto Ditolak",
            message: "Untuk menyimpan foto, silakan izinkan akses Foto di Pengaturan.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Buka Pengaturan", style: .default, handler: { _ in
            if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(appSettings)
            }
        }))
        alert.addAction(UIAlertAction(title: "Batal", style: .cancel))
        self.present(alert, animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds

        let side = min(view.bounds.width, view.bounds.height)
        overlayView.frame = CGRect(
            x: (view.bounds.width - side) / 2,
            y: (view.bounds.height - side) / 2,
            width: side,
            height: side
        )
    }

    func captureSquareFrame() {
        shouldCapture = true
    }
    
    // Callback setelah simpan foto
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            print("Error saving photo: \(error.localizedDescription)")
        } else {
            print("Photo saved successfully!")
        }
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard shouldCapture,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        shouldCapture = false

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        let fullImage = UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .right)

        // Konversi overlayView ke koordinat gambar
        let metadataRect = previewLayer.metadataOutputRectConverted(fromLayerRect: overlayView.frame)
        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)

        let cropRect = CGRect(
            x: metadataRect.origin.x * pixelWidth,
            y: metadataRect.origin.y * pixelHeight,
            width: metadataRect.size.width * pixelWidth,
            height: metadataRect.size.height * pixelHeight
        )

        if let croppedCGImage = cgImage.cropping(to: cropRect) {
            let croppedImage = UIImage(cgImage: croppedCGImage, scale: fullImage.scale, orientation: fullImage.imageOrientation)
            // Simpan ke galeri
            UIImageWriteToSavedPhotosAlbum(croppedImage, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
            delegate?(croppedImage)
        } else {
            UIImageWriteToSavedPhotosAlbum(fullImage, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
            delegate?(fullImage)
        }
    }
}

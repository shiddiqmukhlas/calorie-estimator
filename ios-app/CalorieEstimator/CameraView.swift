import SwiftUI

struct CameraView: UIViewControllerRepresentable {
    var onImageCaptured: (UIImage) -> Void
    @Binding var controller: CameraViewController?

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.delegate = { image in
            onImageCaptured(image)
        }
        DispatchQueue.main.async {
            self.controller = controller
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

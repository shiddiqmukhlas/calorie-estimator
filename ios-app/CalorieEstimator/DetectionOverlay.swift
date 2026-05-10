import SwiftUI

struct DetectionOverlay: UIViewRepresentable {
    var detectionData: DetectionData?
    
    // kalau YOLO input size beda, ganti di sini
    let YOLO_SIZE: CGFloat = 640.0
    let classNames = ["nasiPutih", "dadaAyamFillet", "indomieGoreng", "smblGorengKentang", "tumisKangkung", "tumisTempe"]
    let classColors: [UIColor] = [
        UIColor(red: 0.95, green: 0.38, blue: 0.38, alpha: 1.0),
        UIColor(red: 0.34, green: 0.65, blue: 0.87, alpha: 1.0),
        UIColor(red: 0.53, green: 0.34, blue: 0.87, alpha: 1.0),
        UIColor(red: 0.88, green: 0.34, blue: 0.87, alpha: 1.0),
        UIColor(red: 1.0, green: 0.8, blue: 0.6, alpha: 1),
        UIColor(red: 0.25, green: 0.88, blue: 0.82, alpha: 1),
        UIColor(red: 0.0, green: 0.6, blue: 0.6, alpha: 1),
        UIColor(red: 0.42, green: 0.78, blue: 0.34, alpha: 1.0),
        UIColor(red: 0.98, green: 0.73, blue: 0.31, alpha: 1.0),
        UIColor(red: 0.90, green: 0.50, blue: 0.15, alpha: 1.0)
    ]
    
    // Coordinator untuk menyimpan dan reuse view/layers
    class Coordinator {
        weak var maskContainer: UIView?
        weak var overlayContainer: UIView?
        
        var maskImageViews: [UIImageView] = []
        var boxLayers: [CAShapeLayer] = []
        var labelViews: [UILabel] = []
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    func makeUIView(context: Context) -> UIView {
        let root = UIView()
        root.backgroundColor = .clear
        root.isUserInteractionEnabled = false
        
        // Container untuk mask (di bawah)
        let maskContainer = UIView(frame: root.bounds)
        maskContainer.backgroundColor = .clear
        maskContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        maskContainer.isUserInteractionEnabled = false
        root.addSubview(maskContainer)
        
        // Container untuk bounding box & label (di atas)
        let overlayContainer = UIView(frame: root.bounds)
        overlayContainer.backgroundColor = .clear
        overlayContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlayContainer.isUserInteractionEnabled = false
        root.addSubview(overlayContainer)
        
        context.coordinator.maskContainer = maskContainer
        context.coordinator.overlayContainer = overlayContainer
        
        return root
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Pastikan deteksi valid
        guard let detectionData = detectionData else {
            // jika tidak ada data, bersihkan (jika ada) — jalankan di main
            performOnMain {
                context.coordinator.clearAll()
            }
            return
        }
        
        // Panggil update di Coordinator (aman main-thread)
        performOnMain {
            context.coordinator.update(
                rootView: uiView,
                detectionData: detectionData,
                yoloSize: CGSize(width: YOLO_SIZE, height: YOLO_SIZE),
                classNames: classNames,
                classColors: classColors
            )
        }
    }
    
    // Helper: jalankan closure di main thread (sync jika dipanggil dari background)
    private func performOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.sync { block() }
        }
    }
}

private extension DetectionOverlay.Coordinator {
    func clearAll() {
        // hapus isi containers dengan aman
        maskImageViews.forEach { $0.removeFromSuperview() }
        maskImageViews.removeAll()
        boxLayers.forEach { $0.removeFromSuperlayer() }
        boxLayers.removeAll()
        labelViews.forEach { $0.removeFromSuperview() }
        labelViews.removeAll()
    }
    
    func update(rootView: UIView,
                detectionData: DetectionData,
                yoloSize: CGSize,
                classNames: [String],
                classColors: [UIColor]) {
        
        guard let maskContainer = self.maskContainer ?? rootView.subviews.first,
              let overlayContainer = self.overlayContainer ?? rootView.subviews.last else {
            return
        }
        
        // pastikan containers frame sinkron
        maskContainer.frame = rootView.bounds
        overlayContainer.frame = rootView.bounds
        
        let viewSize = rootView.bounds.size
        if viewSize.width == 0 || viewSize.height == 0 { return }
        
        let detections = detectionData.detections
        let needed = detections.count
        
        // Resize / reuse mask imageviews
        while maskImageViews.count < needed {
            let iv = UIImageView()
            iv.backgroundColor = .clear
            iv.contentMode = .scaleToFill
            iv.isUserInteractionEnabled = false
            maskContainer.addSubview(iv)
            maskImageViews.append(iv)
        }
        while maskImageViews.count > needed {
            let iv = maskImageViews.removeLast()
            iv.removeFromSuperview()
        }
        
        // Resize / reuse box layers
        while boxLayers.count < needed {
            let layer = CAShapeLayer()
            overlayContainer.layer.addSublayer(layer)
            boxLayers.append(layer)
        }
        while boxLayers.count > needed {
            let layer = boxLayers.removeLast()
            layer.removeFromSuperlayer()
        }
        
        // Resize / reuse label views
        while labelViews.count < needed {
            let lbl = UILabel()
            lbl.textColor = .white
            lbl.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            lbl.font = UIFont.boldSystemFont(ofSize: 13)
            lbl.textAlignment = .center
            overlayContainer.addSubview(lbl)
            labelViews.append(lbl)
        }
        while labelViews.count > needed {
            let lbl = labelViews.removeLast()
            lbl.removeFromSuperview()
        }
        
        // Loop detections and update each reusable element
        for i in 0..<needed {
            let detection = detections[i]
            let classId = detection.class_id
            let color = (classId < classColors.count) ? classColors[classId] : UIColor.white
            let className = (classId < classNames.count) ? classNames[classId] : "unknown"
            
            // 1) mask (full YOLO canvas -> scaled to view)
            let maskIV = maskImageViews[i]
            maskIV.frame = CGRect(origin: .zero, size: viewSize) // full-screen so mask aligns with bbox scaling
            
            if let maskBase64 = detection.mask_base64, !maskBase64.isEmpty,
               let maskData = Data(base64Encoded: maskBase64),
               var maskImage = UIImage(data: maskData) {
                
                // if maskImage not YOLO size, resize it (small op)
                if maskImage.size != yoloSize {
                    maskImage = DetectionOverlay.resize(image: maskImage, to: yoloSize)
                }
                
                // colorize on YOLO-sized canvas
                if let colored = DetectionOverlay.colorizeMaskFullYOLO(maskImage: maskImage, color: color, yoloSize: yoloSize, alpha: 0.35) {
                    // scale colored image to view size for display; we can keep colored YOLO-size and let imageView scale
                    let display = DetectionOverlay.resize(image: colored, to: viewSize)
                    maskIV.image = display
                } else {
                    maskIV.image = nil
                }
            } else {
                maskIV.image = nil
            }
            
            // 2) bounding box
            let bbox = detection.bounding_box
            // bbox is in YOLO pixel coords (x_center, y_center, width, height) scaled to YOLO_SIZE
            let xCenter = CGFloat(bbox.x_center)
            let yCenter = CGFloat(bbox.y_center)
            let width = CGFloat(bbox.width)
            let height = CGFloat(bbox.height)
            let rect = CGRect(
                x: xCenter - width / 2,
                y: yCenter - height / 2,
                width: width,
                height: height
            ).applying(CGAffineTransform(scaleX: viewSize.width / yoloSize.width, y: viewSize.height / yoloSize.height))
            
            let boxLayer = boxLayers[i]
            boxLayer.path = UIBezierPath(rect: rect).cgPath
            boxLayer.strokeColor = color.cgColor
            boxLayer.fillColor = UIColor.clear.cgColor
            boxLayer.lineWidth = 2.0
            
            // 3) label
            let lbl = labelViews[i]
            let calories = detection.calories ?? -1
            let weight = detection.weight ?? -1
            if calories >= 0 && weight >= 0 {
                lbl.text = String(format: "%@: %.0fgr~%.0fkkal", className, weight, calories)
            } else {
                lbl.text = className
            }
            lbl.sizeToFit()
            lbl.frame.origin = CGPoint(x: rect.origin.x + max(0,(rect.width - lbl.frame.width)/2), y: rect.origin.y - lbl.frame.height - 5)
        }
    }
    
    // MARK: - helpers: reuse from top-level
}

// MARK: - static helpers (image ops)
private extension DetectionOverlay {
    // resize image
    static func resize(image: UIImage, to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let out = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return out ?? image
    }
    
    // colorize mask on YOLO canvas (maskImage should be grayscale mask with white == mask area)
    static func colorizeMaskFullYOLO(maskImage: UIImage, color: UIColor, yoloSize: CGSize, alpha: CGFloat) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(yoloSize, false, 1.0)
        guard let ctx = UIGraphicsGetCurrentContext(), let cgMask = maskImage.cgImage else {
            UIGraphicsEndImageContext()
            return nil
        }
        ctx.translateBy(x: 0, y: yoloSize.height)
        ctx.scaleBy(x: 1.0, y: -1.0)
        ctx.clip(to: CGRect(origin: .zero, size: yoloSize), mask: cgMask)
        ctx.setFillColor(color.withAlphaComponent(alpha).cgColor)
        ctx.fill(CGRect(origin: .zero, size: yoloSize))
        let out = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return out
    }
}

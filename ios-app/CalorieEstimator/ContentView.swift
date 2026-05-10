import SwiftUI

struct ContentView: View {
    @State private var image: UIImage?
    @State private var detectionData: DetectionData?
    @State private var showCamera = false
    @State private var showImagePicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var cameraController: CameraViewController?
    @State private var isLoading = false   // <<< tambahan state loading

    var body: some View {
        ZStack {
            VStack {
                Text("Calorie Estimator")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 18)
                
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .overlay(
                            ZStack {
                                DetectionOverlay(detectionData: detectionData)
                                if isLoading {
                                    ScanningLoadingView()
                                        .clipped()
                                        .allowsHitTesting(false) // supaya animasi gak ganggu interaksi
                                        .blendMode(.plusLighter)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            , alignment: .center
                        )
                } else {
                    Text("")
                        .padding()
                }


                HStack(spacing: 18) {
                    Button(action: {
                        self.detectionData = nil
                        sourceType = .photoLibrary
                        showImagePicker = true
                    }) {
                        Text("Pilih Foto Makanan")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 20)
                            .background(Color.black)
                            .cornerRadius(11)
                            .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                    }

                    /*Button(action: {
                        self.detectionData = nil
                        showCamera = true
                    }) {
                        Text("Buka Kamera")
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 20)
                            .background(Color.white)
                            .cornerRadius(11)
                            .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }*/
                }
                .padding()


            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            ZStack {
                CameraView(onImageCaptured: { capturedImage in
                    self.image = capturedImage
                    self.sendImageToServer(image: capturedImage)
                    self.showCamera = false
                }, controller: $cameraController)

                VStack {
                    Spacer()
                    Button(action: {
                        cameraController?.captureSquareFrame()
                    }) {
                        Text("📸 Ambil Foto")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .padding()
                    }
                }
            }
        }
        .sheet(isPresented: $showImagePicker, onDismiss: {
            imageSelected()
        }) {
            ImagePicker(image: $image, sourceType: sourceType)
        }
    }

    func imageSelected() {
        if let selectedImage = image {
            self.detectionData = nil // bersihkan overlay
            sendImageToServer(image: selectedImage)
        }
    }

    func sendImageToServer(image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.6) else { return }

        DispatchQueue.main.async {
            isLoading = true  // Mulai loading
        }

        let url = URL(string: "https://e3b95f39c59b.ngrok-free.app/calorie_estimation")! // Ganti sesuai backend
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false  // Selesai loading
            }
            
            if let error = error {
                print("Error sending image: \(error.localizedDescription)")
                return
            }
            if let response = response as? HTTPURLResponse {
                print("Response status code: \(response.statusCode)")
            }
            if let data = data {
                do {
                    let decodedData = try JSONDecoder().decode(DetectionData.self, from: data)
                    DispatchQueue.main.async {
                        self.detectionData = decodedData
                    }
                } catch {
                    print("Failed to decode JSON: \(error)")
                }
            }
        }.resume()
    }
}

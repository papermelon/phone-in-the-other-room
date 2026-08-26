import AVFoundation
import SwiftUI
import UIKit

struct QRCodeScannerView: UIViewControllerRepresentable {
    var onCode: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onCode: (String) -> Void
        private var didReadCode = false

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard !didReadCode,
                  let value = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first?.stringValue else { return }
            didReadCode = true
            onCode(value)
        }
    }
}

final class ScannerViewController: UIViewController {
    weak var delegate: AVCaptureMetadataOutputObjectsDelegate?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(delegate, queue: .main)
        output.metadataObjectTypes = [.qr]
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
        DispatchQueue.global(qos: .userInitiated).async { [session] in session.startRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }
}

struct PhoneBedScannerSheet: View {
    @Binding var isPresented: Bool
    var status: String
    var onCode: (String) -> Void
    @State private var manualCode = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.md) {
                Text("Scan your Wind Down code")
                    .font(AppTypography.title)
                Text("Scan your Wind Down code to confirm the app-access barrier.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.muted)
                    .multilineTextAlignment(.center)
                QRCodeScannerView(onCode: onCode)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                    .frame(height: 280)
                TextField("Code if camera is unavailable", text: $manualCode)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                Button("Use this code") { onCode(manualCode) }
                    .buttonStyle(PixelPrimaryButtonStyle())
                    .disabled(manualCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if !status.isEmpty {
                    Text(status)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(AppSpacing.lg)
            .background(AppColors.paper.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Not now") { isPresented = false }
                }
            }
        }
    }
}

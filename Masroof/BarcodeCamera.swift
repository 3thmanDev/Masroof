import AVFoundation
import Combine
import SwiftUI
import UIKit

/// The back camera, looking for product barcodes in the part of the picture shown on screen.
/// Each barcode is sent once on `codes`; holding it in view doesn't send it again.
final class BarcodeCamera: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    enum Access { case unknown, allowed, denied, unavailable }

    @Published private(set) var access: Access = .unknown
    @Published private(set) var isRunning = false
    @Published private(set) var torchOn = false
    @Published private(set) var hasTorch = false

    let session = AVCaptureSession()
    let codes = PassthroughSubject<String, Never>()
    /// While a price is being typed, barcodes are noticed but not sent.
    var isPaused = false
    weak var preview: AVCaptureVideoPreviewLayer?

    private let queue = DispatchQueue(label: "masroof.camera")
    private let output = AVCaptureMetadataOutput()
    private var device: AVCaptureDevice?
    private var isConfigured = false
    private var lastCode: String?
    private var lastSeen = Date.distantPast

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            run()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { self.run() } else { self.access = .denied }
                }
            }
        default:
            access = .denied
        }
    }

    func stop() {
        isRunning = false
        torchOn = false
        queue.async {
            if let device = self.device, device.hasTorch, device.torchMode == .on,
               (try? device.lockForConfiguration()) != nil {
                device.torchMode = .off
                device.unlockForConfiguration()
            }
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func toggleTorch() {
        let on = !torchOn
        torchOn = on
        queue.async {
            guard let device = self.device, device.hasTorch, (try? device.lockForConfiguration()) != nil else { return }
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        }
    }

    /// Barcodes are only read inside the visible preview, so the shelf around it is ignored.
    func updateSearchArea() {
        guard isRunning, let preview, preview.bounds.width > 0 else { return }
        let rect = preview.metadataOutputRectConverted(fromLayerRect: preview.bounds)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !rect.isNull, rect.width > 0, rect.height > 0 else { return }
        queue.async { self.output.rectOfInterest = rect }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
        let found = objects.compactMap { ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }
        guard let code = found.first(where: { !$0.isEmpty }) else { return }
        let now = Date()
        let stillInView = code == lastCode && now.timeIntervalSince(lastSeen) < 1.5
        lastCode = code
        lastSeen = now
        guard !stillInView, !isPaused else { return }
        codes.send(code)
    }

    private func run() {
        access = .allowed
        queue.async {
            if !self.isConfigured {
                guard self.configure() else {
                    DispatchQueue.main.async { self.access = .unavailable }
                    return
                }
                self.isConfigured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
            let hasTorch = self.device?.hasTorch ?? false
            DispatchQueue.main.async {
                self.hasTorch = hasTorch
                self.isRunning = true
                self.updateSearchArea()
            }
        }
    }

    private func configure() -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input), session.canAddOutput(output) else { return false }
        session.addInput(input)
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        let kinds: [AVMetadataObject.ObjectType] = [.ean13, .ean8, .upce, .code128, .code39, .code93, .itf14, .interleaved2of5]
        output.metadataObjectTypes = kinds.filter { output.availableMetadataObjectTypes.contains($0) }
        self.device = device
        zoomForSmallBarcodes(device)
        return true
    }

    /// From Apple's barcode sample: newer iPhones can't focus closer than about 20 cm, so zoom in
    /// until a 3 cm barcode fills half the picture at that distance.
    private func zoomForSmallBarcodes(_ device: AVCaptureDevice) {
        let closest = Float(device.minimumFocusDistance)
        guard closest > 0, (try? device.lockForConfiguration()) != nil else { return }
        defer { device.unlockForConfiguration() }
        if device.isAutoFocusRangeRestrictionSupported {
            device.autoFocusRangeRestriction = .near
        }
        let halfAngle = device.activeFormat.videoFieldOfView / 2 * .pi / 180
        let distanceForCode = (30 / 0.5) / tan(halfAngle)
        guard distanceForCode < closest else { return }
        let zoom = min(CGFloat(closest / distanceForCode), 2.5, device.activeFormat.videoMaxZoomFactor)
        device.videoZoomFactor = max(1, zoom)
    }
}

/// The live camera picture, filling its frame.
struct CameraPreview: UIViewRepresentable {
    let camera: BarcodeCamera

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        weak var camera: BarcodeCamera?

        override func layoutSubviews() {
            super.layoutSubviews()
            camera?.updateSearchArea()
        }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.session = camera.session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.camera = camera
        camera.preview = view.previewLayer
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}
}

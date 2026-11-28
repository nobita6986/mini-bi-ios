import SwiftUI
import AVFoundation
import CoreImage
import ImageIO
import Vision
import PhotosUI

// MARK: - Camera & Vision CCCD QR + MRZ + OCR Scanner View
// Uses 100% native AVFoundation + CoreImage + Vision for 2021 & 2024 Vietnamese CCCD cards.

public struct CccdQrScannerSheet: View {
    public let onDecoded: (String, CccdQrData) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedZoomFactor: CGFloat = 2.0
    @State private var isTorchOn: Bool = false
    @State private var isProcessingPhoto: Bool = false
    @State private var statusMessage: String = "Đưa mã QR (hoặc 3 dòng chữ IDVNM... mặt sau nếu QR mờ) vào khung ngắm, hoặc chọn ảnh CCCD từ Thư viện"
    @State private var manualQrInput: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?

    private static let sharedCiContext = CIContext(options: [.useSoftwareRenderer: false])
    private static let qrCiDetector: CIDetector? = CIDetector(
        ofType: CIDetectorTypeQRCode,
        context: sharedCiContext,
        options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
    )

    public init(onDecoded: @escaping (String, CccdQrData) -> Void) {
        self.onDecoded = onDecoded
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Live Camera Preview with AVFoundation + Vision (QR + MRZ fallback + Macro lens)
                ZStack {
                    CccdCameraPreviewRepresentable(
                        zoomFactor: selectedZoomFactor,
                        isTorchOn: isTorchOn,
                        onRawQrDetected: { rawValue in
                            handleRawCandidate(rawValue)
                        },
                        onCccdDataDetected: { decodedData in
                            deliverDecodedResult(decodedData)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: HrpDesignTokens.radiusHero, style: .continuous))

                    // Dimmed surrounding cutout & 4 Corner Brackets Reticle Overlay
                    QrViewfinderOverlay(cutoutSize: 224)

                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            ForEach([1.0, 2.0, 3.0], id: \.self) { zoom in
                                let isSelected = selectedZoomFactor == CGFloat(zoom)
                                Button {
                                    HapticsManager.selection()
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        selectedZoomFactor = CGFloat(zoom)
                                    }
                                } label: {
                                    Text("\(Int(zoom))x")
                                        .font(.caption.weight(.bold))
                                        .monospacedDigit()
                                        .frame(width: 44, height: 44)
                                        .background(isSelected ? Color.white : Color.black.opacity(0.55))
                                        .foregroundColor(isSelected ? .black : .white)
                                        .clipShape(Circle())
                                        .contentShape(Circle())
                                }
                                .buttonStyle(HrpPressableButtonStyle())
                            }

                            Button {
                                HapticsManager.selection()
                                isTorchOn.toggle()
                            } label: {
                                Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .frame(width: 44, height: 44)
                                    .background(isTorchOn ? Color.yellow : Color.black.opacity(0.55))
                                    .foregroundColor(isTorchOn ? .black : .white)
                                    .clipShape(Circle())
                                    .contentShape(Circle())
                            }
                            .buttonStyle(HrpPressableButtonStyle())
                        }
                        .padding(.bottom, 12)
                    }
                }
                .frame(height: 320)
                .padding(.horizontal, 16)

                Text(statusMessage)
                    .font(.caption.weight(.medium))
                    .foregroundColor(SemanticColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                // Pick QR/MRZ/OCR from Photo Library (multi-pass CoreImage + Vision off-main-thread)
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack(spacing: 8) {
                        if isProcessingPhoto {
                            ProgressView()
                                .scaleEffect(0.85)
                        } else {
                            Image(systemName: "photo.on.rectangle.angled")
                        }
                        Text(isProcessingPhoto ? "Đang phân tích ảnh CCCD..." : "Chọn ảnh CCCD từ Thư viện")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Color(hex: 0xEBF3FB))
                    .foregroundColor(Color(hex: 0x1E6BB8))
                    .clipShape(RoundedRectangle(cornerRadius: HrpDesignTokens.radiusMD, style: .continuous))
                }
                .disabled(isProcessingPhoto)
                .padding(.horizontal, 16)
                .onChange(of: selectedPhotoItem) { newItem in
                    guard let newItem else { return }
                    isProcessingPhoto = true
                    Task {
                        let data = try? await newItem.loadTransferable(type: Data.self)
                        let decoded: CccdQrData? = await Task.detached(priority: .userInitiated) {
                            guard let data else { return nil }
                            return Self.detectCccdFromImageData(data)
                        }.value
                        isProcessingPhoto = false
                        selectedPhotoItem = nil
                        if let decoded {
                            deliverDecodedResult(decoded)
                        } else {
                            HapticsManager.error()
                            statusMessage = "Không đọc được mã QR hoặc thông tin CCCD hợp lệ trên ảnh đã chọn."
                        }
                    }
                }

                // Fallback Manual Paste / Testing Input
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hoặc dán chuỗi QR / MRZ CCCD trực tiếp:")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(SemanticColors.textSecondary)
                    HStack {
                        TextField("034098001234||Nguyễn Văn A|...", text: $manualQrInput)
                            .submitLabel(.done)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundColor(SemanticColors.textPrimary)
                            .padding(10)
                            .background(SemanticColors.surfaceMuted)
                            .clipShape(RoundedRectangle(cornerRadius: HrpDesignTokens.radiusXS, style: .continuous))
                        Button("Áp dụng") {
                            KeyboardDismissal.dismiss()
                            handleRawCandidate(manualQrInput)
                        }
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 40)
                        .background(Color(hex: 0x1E6BB8))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: HrpDesignTokens.radiusXS, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)

                Spacer()
            }
            .padding(.top, 12)
            .dismissKeyboardOnTapOutside()
            .navigationTitle("Quét mã QR / CCCD")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") {
                        KeyboardDismissal.dismiss()
                        dismiss()
                    }
                }
            }
        }
        .hrpSheetPresentation(detents: [.large])
    }

    private func handleRawCandidate(_ raw: String) {
        if let parsed = CccdQrDecoder.parse(raw) {
            deliverDecodedResult(parsed, overrideRaw: raw)
        } else {
            HapticsManager.error()
            statusMessage = "Mã QR không đúng định dạng CCCD Việt Nam. Vui lòng thử lại."
        }
    }

    private func deliverDecodedResult(_ parsed: CccdQrData, overrideRaw: String? = nil) {
        HapticsManager.success()
        onDecoded(overrideRaw ?? parsed.rawQr, parsed)
        dismiss()
    }

    // MARK: - Multi-Pass Image QR Detection & MRZ + OCR Fallback

    public static func detectQrFromImageData(_ data: Data) -> String? {
        guard let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else {
            return nil
        }
        let orientation = cgImagePropertyOrientation(from: uiImage.imageOrientation)

        // Pass 1: Full image with proper EXIF orientation
        if let payload = performQrDetection(on: cgImage, orientation: orientation) {
            return payload
        }

        // Normalize into upright CGImage for multi-corner cropping & CoreImage enhancement
        guard let uprightCg = renderUprightCgImage(from: cgImage, orientation: orientation) else {
            return nil
        }

        // Pass 2: 2.5x upscaled crops across all 4 corners + center (handles vertically held / rotated 2021 cards)
        let cropRects = normalizedMultiCornerCropRects(width: uprightCg.width, height: uprightCg.height)
        for rect in cropRects {
            if let cropped = uprightCg.cropping(to: rect),
               let upscaled = upscaleCgImage(cropped, scale: 2.5),
               let payload = performQrDetection(on: upscaled, orientation: .up) {
                return payload
            }
        }

        // Pass 3: Cyan/teal security-pattern suppression via CoreImage (targets 2021 CCCD background lines)
        if let enhancedFull = suppressCyanPattern(on: uprightCg),
           let payload = performQrDetection(on: enhancedFull, orientation: .up) {
            return payload
        }
        for rect in cropRects {
            if let cropped = uprightCg.cropping(to: rect),
               let upscaled = upscaleCgImage(cropped, scale: 2.5),
               let enhancedCrop = suppressCyanPattern(on: upscaled),
               let payload = performQrDetection(on: enhancedCrop, orientation: .up) {
                return payload
            }
        }

        return nil
    }

    public static func detectCccdFromImageData(_ data: Data) -> CccdQrData? {
        if let qrRaw = detectQrFromImageData(data),
           let parsedQr = CccdQrDecoder.parse(qrRaw) {
            return parsedQr
        }

        guard let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else {
            return nil
        }
        let orientation = cgImagePropertyOrientation(from: uiImage.imageOrientation)
        guard let uprightCg = renderUprightCgImage(from: cgImage, orientation: orientation) else {
            return nil
        }

        // Try upright first, then 90-degree rotations for sideways/vertically held cards
        for tryOrientation: CGImagePropertyOrientation in [.up, .right, .left] {
            let lines = recognizeTextLines(
                on: uprightCg,
                orientation: tryOrientation,
                languages: ["vi-VN", "en-US"]
            )
            if let parsed = CccdQrDecoder.parseFromRecognizedTextLines(lines) {
                return parsed
            }
        }

        return nil
    }

    private static func performQrDetection(on cgImage: CGImage, orientation: CGImagePropertyOrientation) -> String? {
        var detectedPayload: String?
        let request = VNDetectBarcodesRequest { req, _ in
            guard let results = req.results as? [VNBarcodeObservation] else { return }
            for obs in results {
                if let payload = obs.payloadStringValue, CccdQrDecoder.parse(payload) != nil {
                    detectedPayload = payload
                    break
                }
            }
        }
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        try? handler.perform([request])
        if let detectedPayload {
            return detectedPayload
        }

        // CoreImage CIDetector fallback (works without ANE/E5RT and excels on high-contrast crops)
        if let detector = qrCiDetector {
            let ciImg = orientation == .up ? CIImage(cgImage: cgImage) : CIImage(cgImage: cgImage).oriented(orientation)
            let features = detector.features(in: ciImg)
            for case let qrFeature as CIQRCodeFeature in features {
                if let payload = qrFeature.messageString, CccdQrDecoder.parse(payload) != nil {
                    return payload
                }
            }
        }
        return nil
    }

    private static func recognizeTextLines(
        on cgImage: CGImage,
        orientation: CGImagePropertyOrientation,
        languages: [String]
    ) -> [String] {
        var recognized: [String] = []
        let request = VNRecognizeTextRequest { req, _ in
            guard let observations = req.results as? [VNRecognizedTextObservation] else { return }
            let sorted = observations.sorted { a, b in
                let yDiff = abs(a.boundingBox.midY - b.boundingBox.midY)
                if yDiff > 0.012 {
                    return a.boundingBox.midY > b.boundingBox.midY
                }
                return a.boundingBox.minX < b.boundingBox.minX
            }
            for obs in sorted {
                if let top = obs.topCandidates(1).first?.string {
                    let trimmed = top.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        recognized.append(trimmed)
                    }
                }
            }
        }
        request.recognitionLevel = .accurate
        request.recognitionLanguages = languages
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        try? handler.perform([request])
        return recognized
    }

    private static func normalizedMultiCornerCropRects(width: Int, height: Int) -> [CGRect] {
        let w = CGFloat(width)
        let h = CGFloat(height)
        guard w >= 40, h >= 40 else { return [] }
        let cw = w * 0.45
        let ch = h * 0.45
        return [
            CGRect(x: w - cw, y: 0, width: cw, height: ch),                  // Top-Right
            CGRect(x: w - cw, y: h - ch, width: cw, height: ch),             // Bottom-Right
            CGRect(x: 0, y: 0, width: cw, height: ch),                       // Top-Left
            CGRect(x: 0, y: h - ch, width: cw, height: ch),                  // Bottom-Left
            CGRect(x: (w - cw) / 2, y: (h - ch) / 2, width: cw, height: ch)  // Center
        ].map { $0.integral }
    }

    private static func renderUprightCgImage(
        from cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) -> CGImage? {
        if orientation == .up {
            return cgImage
        }
        let ci = CIImage(cgImage: cgImage).oriented(orientation)
        return sharedCiContext.createCGImage(ci, from: ci.extent)
    }

    private static func upscaleCgImage(_ cgImage: CGImage, scale: CGFloat) -> CGImage? {
        let ci = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CILanczosScaleTransform") else {
            return cgImage
        }
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(scale, forKey: kCIInputScaleKey)
        filter.setValue(1.0, forKey: kCIInputAspectRatioKey)
        guard let output = filter.outputImage else { return cgImage }
        return sharedCiContext.createCGImage(output, from: output.extent)
    }

    /// Suppresses teal/cyan security waves on 2021 CCCD cards using Green/Blue projection + high contrast.
    private static func suppressCyanPattern(on cgImage: CGImage) -> CGImage? {
        let ci = CIImage(cgImage: cgImage)
        guard let matrix = CIFilter(name: "CIColorMatrix") else { return nil }
        let gbVector = CIVector(x: 0.0, y: 0.55, z: 0.45, w: 0.0)
        matrix.setValue(ci, forKey: kCIInputImageKey)
        matrix.setValue(gbVector, forKey: "inputRVector")
        matrix.setValue(gbVector, forKey: "inputGVector")
        matrix.setValue(gbVector, forKey: "inputBVector")
        matrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
        guard let projected = matrix.outputImage else { return nil }

        guard let controls = CIFilter(name: "CIColorControls") else {
            return sharedCiContext.createCGImage(projected, from: projected.extent)
        }
        controls.setValue(projected, forKey: kCIInputImageKey)
        controls.setValue(0.0, forKey: kCIInputSaturationKey)
        controls.setValue(0.05, forKey: kCIInputBrightnessKey)
        controls.setValue(1.8, forKey: kCIInputContrastKey)
        guard let output = controls.outputImage else { return nil }
        return sharedCiContext.createCGImage(output, from: output.extent)
    }

    private static func cgImagePropertyOrientation(from orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

// MARK: - UIKit AVCaptureSession Wrapper

struct CccdCameraPreviewRepresentable: UIViewControllerRepresentable {
    let zoomFactor: CGFloat
    let isTorchOn: Bool
    let onRawQrDetected: (String) -> Void
    let onCccdDataDetected: (CccdQrData) -> Void

    func makeUIViewController(context: Context) -> CccdCameraViewController {
        let vc = CccdCameraViewController()
        vc.onRawQrDetected = onRawQrDetected
        vc.onCccdDataDetected = onCccdDataDetected
        return vc
    }

    func updateUIViewController(_ uiViewController: CccdCameraViewController, context: Context) {
        uiViewController.applyZoomAndTorch(zoomFactor: zoomFactor, isTorchOn: isTorchOn)
    }
}

final class CccdCameraViewController: UIViewController,
    AVCaptureMetadataOutputObjectsDelegate,
    AVCaptureVideoDataOutputSampleBufferDelegate {
    var onRawQrDetected: ((String) -> Void)?
    var onCccdDataDetected: ((CccdQrData) -> Void)?

    private let captureSession = AVCaptureSession()
    private let videoDataQueue = DispatchQueue(label: "com.aistudio.minibi.cccd.videodata", qos: .userInitiated)
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoDevice: AVCaptureDevice?
    private var baseWideZoomFactor: CGFloat = 1.0
    private var requestedUiZoomFactor: CGFloat = 2.0
    private var requestedTorchOn: Bool = false
    private var hasDeliveredResult = false
    private var lastFrameAnalysisTime: CFAbsoluteTime = 0
    private var isAnalyzingFrame = false
    private var focusRingLayer: CAShapeLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let tap = UITapGestureRecognizer(target: self, action: #selector(handlePreviewTap(_:)))
        view.addGestureRecognizer(tap)
        configureCaptureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    private func discoverBestMacroCapableCamera() -> AVCaptureDevice? {
        let preferredTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: preferredTypes,
            mediaType: .video,
            position: .back
        )
        for deviceType in preferredTypes {
            if let matched = discovery.devices.first(where: { $0.deviceType == deviceType }) {
                return matched
            }
        }
        return discovery.devices.first ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    private func configureCaptureSession() {
        guard AVCaptureDevice.authorizationStatus(for: .video) != .restricted else { return }

        guard let device = discoverBestMacroCapableCamera(),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else {
            return
        }

        videoDevice = device
        if device.deviceType == .builtInTripleCamera || device.deviceType == .builtInDualWideCamera,
           let switchOver = device.virtualDeviceSwitchOverVideoZoomFactors.first {
            baseWideZoomFactor = max(1.0, CGFloat(truncating: switchOver))
        } else {
            baseWideZoomFactor = 1.0
        }

        captureSession.beginConfiguration()
        if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        }
        captureSession.addInput(input)

        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            if metadataOutput.availableMetadataObjectTypes.contains(.qr) {
                metadataOutput.metadataObjectTypes = [.qr]
            }
        }

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: videoDataQueue)
        }
        captureSession.commitConfiguration()

        configureNearFocusDefaults(on: device)
        applyZoomAndTorch(zoomFactor: requestedUiZoomFactor, isTorchOn: requestedTorchOn)

        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    private func configureNearFocusDefaults(on device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .near
            }
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.isSubjectAreaChangeMonitoringEnabled = true
            device.unlockForConfiguration()
        } catch {
            // Ignore configuration lock error on simulator
        }
    }

    @objc private func handlePreviewTap(_ gesture: UITapGestureRecognizer) {
        guard let device = videoDevice, let previewLayer else { return }
        let touchPoint = gesture.location(in: view)
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: touchPoint)
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = devicePoint
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                } else if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = devicePoint
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
            }
            device.unlockForConfiguration()
        } catch {
            // Ignore lock error
        }
        showTapFocusIndicator(at: touchPoint)
    }

    private func showTapFocusIndicator(at point: CGPoint) {
        focusRingLayer?.removeFromSuperlayer()
        let ringSize: CGFloat = 64
        let ringRect = CGRect(x: point.x - ringSize / 2, y: point.y - ringSize / 2, width: ringSize, height: ringSize)
        let ring = CAShapeLayer()
        ring.path = UIBezierPath(roundedRect: ringRect, cornerRadius: 10).cgPath
        ring.strokeColor = UIColor.systemYellow.cgColor
        ring.fillColor = UIColor.clear.cgColor
        ring.lineWidth = 2
        view.layer.addSublayer(ring)
        focusRingLayer = ring

        UIView.animate(withDuration: 0.2) { }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak ring] in
            ring?.removeFromSuperlayer()
        }
    }

    func applyZoomAndTorch(zoomFactor: CGFloat, isTorchOn: Bool) {
        requestedUiZoomFactor = zoomFactor
        requestedTorchOn = isTorchOn
        guard let device = videoDevice else { return }
        do {
            try device.lockForConfiguration()
            let hardwareZoom = zoomFactor * baseWideZoomFactor
            let maxZoom = min(max(4.0, baseWideZoomFactor * 4.0), device.activeFormat.videoMaxZoomFactor)
            let clampedZoom = min(max(1.0, hardwareZoom), maxZoom)
            device.videoZoomFactor = clampedZoom
            if device.hasTorch {
                device.torchMode = isTorchOn ? .on : .off
            }
            device.unlockForConfiguration()
        } catch {
            // Ignore configuration lock error on simulator
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasDeliveredResult else { return }
        for obj in metadataObjects {
            if let readable = obj as? AVMetadataMachineReadableCodeObject,
               let rawValue = readable.stringValue,
               CccdQrDecoder.parse(rawValue) != nil {
                hasDeliveredResult = true
                captureSession.stopRunning()
                onRawQrDetected?(rawValue)
                break
            }
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CFAbsoluteTimeGetCurrent()
        guard !hasDeliveredResult,
              !isAnalyzingFrame,
              now - lastFrameAnalysisTime >= 0.65,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        lastFrameAnalysisTime = now
        isAnalyzingFrame = true
        defer { isAnalyzingFrame = false }

        // 1. Vision QR fallback for small 10mm 2021 QR codes
        var detectedQrPayload: String?
        let qrRequest = VNDetectBarcodesRequest { req, _ in
            guard let results = req.results as? [VNBarcodeObservation] else { return }
            for obs in results {
                if let payload = obs.payloadStringValue, CccdQrDecoder.parse(payload) != nil {
                    detectedQrPayload = payload
                    break
                }
            }
        }
        qrRequest.symbologies = [.qr]

        // 2. Vision MRZ fallback when user points camera at back-side `IDVNM...` 3 lines
        var recognizedLines: [String] = []
        let textRequest = VNRecognizeTextRequest { req, _ in
            guard let obsList = req.results as? [VNRecognizedTextObservation] else { return }
            let sorted = obsList.sorted { $0.boundingBox.midY > $1.boundingBox.midY }
            recognizedLines = sorted.compactMap { $0.topCandidates(1).first?.string }
        }
        textRequest.recognitionLevel = .accurate
        textRequest.recognitionLanguages = ["en-US"]
        textRequest.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        try? handler.perform([qrRequest, textRequest])

        if let detectedQrPayload {
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.hasDeliveredResult else { return }
                self.hasDeliveredResult = true
                self.captureSession.stopRunning()
                self.onRawQrDetected?(detectedQrPayload)
            }
            return
        }

        if let mrzData = CccdQrDecoder.parseMrzFromLines(recognizedLines) {
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.hasDeliveredResult else { return }
                self.hasDeliveredResult = true
                self.captureSession.stopRunning()
                self.onCccdDataDetected?(mrzData)
            }
        }
    }
}

// MARK: - Viewfinder Overlay with Dimmed Cutout & 4 Corner Brackets

private struct QrViewfinderOverlay: View {
    let cutoutSize: CGFloat

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(
                x: (geo.size.width - cutoutSize) / 2,
                y: (geo.size.height - cutoutSize) / 2 - 14,
                width: cutoutSize,
                height: cutoutSize
            )

            ZStack {
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: geo.size))
                    path.addRoundedRect(
                        in: rect,
                        cornerSize: CGSize(width: HrpDesignTokens.radiusCard, height: HrpDesignTokens.radiusCard)
                    )
                }
                .fill(Color.black.opacity(0.42), style: FillStyle(eoFill: true))

                RoundedRectangle(cornerRadius: HrpDesignTokens.radiusCard, style: .continuous)
                    .stroke(Color.white.opacity(0.32), lineWidth: 1)
                    .frame(width: cutoutSize, height: cutoutSize)
                    .position(x: rect.midX, y: rect.midY)

                QrCornerBracketsShape(cornerRadius: HrpDesignTokens.radiusCard, armLength: 28)
                    .stroke(Color(hex: 0x22C55E), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                    .frame(width: cutoutSize, height: cutoutSize)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
        .allowsHitTesting(false)
        .clipShape(RoundedRectangle(cornerRadius: HrpDesignTokens.radiusHero, style: .continuous))
    }
}

private struct QrCornerBracketsShape: Shape {
    let cornerRadius: CGFloat
    let armLength: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(cornerRadius, min(rect.width, rect.height) / 4)
        let l = min(armLength, min(rect.width, rect.height) / 2 - r)

        // Top-Left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + r + l))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + r + l, y: rect.minY))

        // Top-Right
        p.move(to: CGPoint(x: rect.maxX - r - l, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + r + l))

        // Bottom-Right
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - r - l))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - r - l, y: rect.maxY))

        // Bottom-Left
        p.move(to: CGPoint(x: rect.minX + r + l, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r - l))

        return p
    }
}

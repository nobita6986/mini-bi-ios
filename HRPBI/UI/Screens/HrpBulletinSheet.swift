import SwiftUI
import UIKit
import PDFKit

// MARK: - Mockup Media Generator (2-Page PDF via UIGraphicsPDFRenderer + Infographic Image via UIGraphicsImageRenderer)

public enum HrpBulletinMockupMediaGenerator {
    private static var cachedImages: [String: UIImage] = [:]

    public static func sampleImage(
        for attachment: HrpBulletinAttachment,
        bulletin: HrpBulletinItem
    ) -> UIImage {
        if let cached = cachedImages[attachment.id] {
            return cached
        }

        let size = CGSize(width: 960, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let bounds = CGRect(origin: .zero, size: size)

            // Soft warm background
            UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1.0).setFill()
            cg.fill(bounds)

            // Header bar
            let headerRect = CGRect(x: 0, y: 0, width: size.width, height: 92)
            let primaryColor: UIColor = {
                switch bulletin.category {
                case .holidaySchedule:
                    return UIColor(red: 0.01, green: 0.52, blue: 0.78, alpha: 1.0)
                case .internalPolicy:
                    return UIColor(red: 0.08, green: 0.50, blue: 0.24, alpha: 1.0)
                default:
                    return UIColor(red: 0.92, green: 0.35, blue: 0.05, alpha: 1.0)
                }
            }()
            primaryColor.setFill()
            cg.fill(headerRect)

            let headerAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .heavy),
                .foregroundColor: UIColor.white
            ]
            let subHeaderAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.92)
            ]
            ("HRPARTNER VIỆT NAM · BẢN TIN NỘI BỘ" as NSString).draw(
                at: CGPoint(x: 32, y: 20),
                withAttributes: headerAttr
            )
            ("Ngày phát hành: \(bulletin.publishedDateDisplay) · \(bulletin.categoryDisplay)" as NSString).draw(
                at: CGPoint(x: 32, y: 52),
                withAttributes: subHeaderAttr
            )

            // Main card container
            let cardRect = CGRect(x: 28, y: 114, width: size.width - 56, height: size.height - 142)
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 20)
            UIColor.white.setFill()
            cardPath.fill()
            UIColor(white: 0.86, alpha: 1.0).setStroke()
            cardPath.lineWidth = 1.5
            cardPath.stroke()

            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor(white: 0.12, alpha: 1.0)
            ]
            (attachment.title as NSString).draw(
                in: CGRect(x: 56, y: 138, width: size.width - 112, height: 64),
                withAttributes: titleAttr
            )

            let summaryAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                .foregroundColor: UIColor(white: 0.32, alpha: 1.0)
            ]
            (bulletin.summary as NSString).draw(
                in: CGRect(x: 56, y: 196, width: size.width - 112, height: 54),
                withAttributes: summaryAttr
            )

            // 3 visual highlight boxes from contentSections
            let boxTop: CGFloat = 262
            let boxHeight: CGFloat = 224
            let spacing: CGFloat = 18
            let totalWidth = size.width - 112
            let colCount = min(max(bulletin.contentSections.count, 1), 3)
            let boxWidth = (totalWidth - CGFloat(colCount - 1) * spacing) / CGFloat(colCount)

            for idx in 0..<colCount {
                let x = 56 + CGFloat(idx) * (boxWidth + spacing)
                let boxRect = CGRect(x: x, y: boxTop, width: boxWidth, height: boxHeight)
                let boxPath = UIBezierPath(roundedRect: boxRect, cornerRadius: 14)
                primaryColor.withAlphaComponent(0.07).setFill()
                boxPath.fill()
                primaryColor.withAlphaComponent(0.28).setStroke()
                boxPath.lineWidth = 1.2
                boxPath.stroke()

                let badgeAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 15, weight: .bold),
                    .foregroundColor: primaryColor
                ]
                ("MỤC 0\(idx + 1)" as NSString).draw(
                    at: CGPoint(x: x + 16, y: boxTop + 16),
                    withAttributes: badgeAttr
                )

                let bodyText = bulletin.contentSections[idx]
                let bodyAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14.5, weight: .medium),
                    .foregroundColor: UIColor(white: 0.18, alpha: 1.0)
                ]
                (bodyText as NSString).draw(
                    in: CGRect(x: x + 16, y: boxTop + 46, width: boxWidth - 32, height: boxHeight - 60),
                    withAttributes: bodyAttr
                )
            }

            let footerAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: UIColor(white: 0.45, alpha: 1.0)
            ]
            ("\(bulletin.authorDisplay) · Chạm 2 lần hoặc chụm 2 ngón tay để phóng to chi tiết" as NSString).draw(
                at: CGPoint(x: 56, y: size.height - 62),
                withAttributes: footerAttr
            )
        }

        cachedImages[attachment.id] = image
        return image
    }

    @discardableResult
    public static func samplePdfUrl(
        for attachment: HrpBulletinAttachment,
        bulletin: HrpBulletinItem
    ) -> URL {
        let safeName = attachment.fileName
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = safeName.hasSuffix(".pdf") ? safeName : "\(attachment.id).pdf"
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("hrpbi_bulletin_pdfs", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let fileUrl = folder.appendingPathComponent(resolvedName)

        if FileManager.default.fileExists(atPath: fileUrl.path),
           let existingDoc = PDFDocument(url: fileUrl),
           existingDoc.pageCount == 2 {
            return fileUrl
        }

        let pageBounds = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // Standard A4
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: attachment.title,
            kCGPDFContextAuthor as String: bulletin.authorDisplay,
            kCGPDFContextCreator as String: "HRP BI iOS"
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds, format: format)
        let data = renderer.pdfData { ctx in
            // ==================== PAGE 1 / 2 ====================
            ctx.beginPage()
            drawPdfPage1(in: pageBounds, attachment: attachment, bulletin: bulletin)

            // ==================== PAGE 2 / 2 ====================
            ctx.beginPage()
            drawPdfPage2(in: pageBounds, attachment: attachment, bulletin: bulletin)
        }

        try? data.write(to: fileUrl, options: .atomic)
        return fileUrl
    }

    private static func drawPdfPage1(
        in bounds: CGRect,
        attachment: HrpBulletinAttachment,
        bulletin: HrpBulletinItem
    ) {
        let brandOrange = UIColor(red: 0.92, green: 0.35, blue: 0.05, alpha: 1.0)
        let darkText = UIColor(white: 0.12, alpha: 1.0)
        let secondaryText = UIColor(white: 0.35, alpha: 1.0)

        // Top header national motto & company name
        let companyAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: darkText
        ]
        let mottoAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: darkText
        ]
        let subMottoAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: secondaryText
        ]

        ("CÔNG TY CỔ PHẦN HRPARTNER VIỆT NAM" as NSString).draw(
            at: CGPoint(x: 42, y: 42),
            withAttributes: companyAttr
        )
        ("Số: 112/2026/TB-HRP" as NSString).draw(
            at: CGPoint(x: 42, y: 58),
            withAttributes: subMottoAttr
        )

        ("CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM" as NSString).draw(
            at: CGPoint(x: 310, y: 42),
            withAttributes: mottoAttr
        )
        ("Độc lập - Tự do - Hạnh phúc" as NSString).draw(
            at: CGPoint(x: 356, y: 58),
            withAttributes: subMottoAttr
        )
        ("Hà Nội, ngày \(bulletin.publishedDateDisplay)" as NSString).draw(
            at: CGPoint(x: 348, y: 76),
            withAttributes: subMottoAttr
        )

        // Divider line
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: 42, y: 102))
        linePath.addLine(to: CGPoint(x: bounds.width - 42, y: 102))
        brandOrange.setStroke()
        linePath.lineWidth = 1.5
        linePath.stroke()

        // Document title
        let docTitleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17, weight: .heavy),
            .foregroundColor: brandOrange
        ]
        ("THÔNG BÁO & BẢN TIN NỘI BỘ HRPARTNER" as NSString).draw(
            at: CGPoint(x: 42, y: 120),
            withAttributes: docTitleAttr
        )

        let mainTitleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .bold),
            .foregroundColor: darkText
        ]
        (attachment.title as NSString).draw(
            in: CGRect(x: 42, y: 146, width: bounds.width - 84, height: 44),
            withAttributes: mainTitleAttr
        )

        // Summary box
        let summaryBox = CGRect(x: 42, y: 196, width: bounds.width - 84, height: 72)
        let summaryPath = UIBezierPath(roundedRect: summaryBox, cornerRadius: 10)
        UIColor(red: 1.0, green: 0.96, blue: 0.92, alpha: 1.0).setFill()
        summaryPath.fill()
        brandOrange.withAlphaComponent(0.35).setStroke()
        summaryPath.lineWidth = 1
        summaryPath.stroke()

        let summaryTextAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11.5, weight: .medium),
            .foregroundColor: darkText
        ]
        ("Tóm tắt nội dung: \(bulletin.summary)" as NSString).draw(
            in: CGRect(x: 54, y: 208, width: bounds.width - 108, height: 50),
            withAttributes: summaryTextAttr
        )

        // Content sections
        let sectionHeaderAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: darkText
        ]
        ("I. NỘI DUNG TRIỂN KHAI CHI TIẾT" as NSString).draw(
            at: CGPoint(x: 42, y: 286),
            withAttributes: sectionHeaderAttr
        )

        let paragraphAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11.5, weight: .regular),
            .foregroundColor: darkText
        ]

        var currentY: CGFloat = 312
        for section in bulletin.contentSections {
            let sectionRect = CGRect(x: 42, y: currentY, width: bounds.width - 84, height: 68)
            let box = UIBezierPath(roundedRect: sectionRect, cornerRadius: 8)
            UIColor(white: 0.97, alpha: 1.0).setFill()
            box.fill()
            UIColor(white: 0.88, alpha: 1.0).setStroke()
            box.lineWidth = 0.8
            box.stroke()

            (section as NSString).draw(
                in: CGRect(x: 54, y: currentY + 10, width: bounds.width - 108, height: 50),
                withAttributes: paragraphAttr
            )
            currentY += 80
        }

        // Footer page 1
        drawPdfFooter(in: bounds, pageNumber: 1, totalPages: 2, author: bulletin.authorDisplay)
    }

    private static func drawPdfPage2(
        in bounds: CGRect,
        attachment: HrpBulletinAttachment,
        bulletin: HrpBulletinItem
    ) {
        let brandOrange = UIColor(red: 0.92, green: 0.35, blue: 0.05, alpha: 1.0)
        let darkText = UIColor(white: 0.12, alpha: 1.0)
        let secondaryText = UIColor(white: 0.35, alpha: 1.0)

        let sectionHeaderAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: darkText
        ]
        ("II. PHÂN CÔNG PHỐI HỢP & HƯỚNG DẪN TRÊN ỨNG DỤNG HRP BI" as NSString).draw(
            at: CGPoint(x: 42, y: 48),
            withAttributes: sectionHeaderAttr
        )

        let rows: [(String, String)] = [
            ("1. Bộ phận Tuyển dụng", "Rà soát danh sách ứng viên hẹn lịch phỏng vấn và cập nhật hồ sơ CCCD đầy đủ trên ứng dụng HRP BI."),
            ("2. Quản lý dự án (QLDA)", "Theo dõi quân số đi làm thực tế tại các KCN, xác nhận trạng thái Đang làm / Đang chờ việc / Đã nghỉ trước 17:00."),
            ("3. Hành chính - Nhân sự", "Tổng hợp bảng chấm công GPS/Wi-Fi, duyệt đơn nghỉ phép và giải trình chấm công đúng hạn khóa sổ."),
            ("4. Hỗ trợ kỹ thuật BI", "Đảm bảo đồng bộ dữ liệu báo cáo thời gian thực trên cả 2 nền tảng iOS và Android.")
        ]

        var y: CGFloat = 80
        for (dept, taskText) in rows {
            let rowRect = CGRect(x: 42, y: y, width: bounds.width - 84, height: 64)
            let path = UIBezierPath(roundedRect: rowRect, cornerRadius: 8)
            UIColor(white: 0.97, alpha: 1.0).setFill()
            path.fill()
            UIColor(white: 0.86, alpha: 1.0).setStroke()
            path.lineWidth = 0.8
            path.stroke()

            let deptAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11.5, weight: .bold),
                .foregroundColor: brandOrange
            ]
            let taskAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: darkText
            ]
            (dept as NSString).draw(at: CGPoint(x: 54, y: y + 10), withAttributes: deptAttr)
            (taskText as NSString).draw(
                in: CGRect(x: 54, y: y + 28, width: bounds.width - 108, height: 32),
                withAttributes: taskAttr
            )
            y += 76
        }

        // Recipients & Signature block
        let recipientAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10.5, weight: .regular),
            .foregroundColor: secondaryText
        ]
        let recipientsText = """
        Nơi nhận:
        - Ban Giám đốc (để báo cáo);
        - Các Trưởng nhóm Tuyển dụng & QLDA KCN (để thực hiện);
        - Lưu: VT, HCNS.
        """
        (recipientsText as NSString).draw(
            in: CGRect(x: 42, y: 420, width: 240, height: 90),
            withAttributes: recipientAttr
        )

        let signHeaderAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11.5, weight: .bold),
            .foregroundColor: darkText
        ]
        ("TM. \(bulletin.authorDisplay.uppercased())" as NSString).draw(
            at: CGPoint(x: 330, y: 420),
            withAttributes: signHeaderAttr
        )

        // Simulated red stamp circle
        let stampRect = CGRect(x: 356, y: 448, width: 140, height: 54)
        let stampPath = UIBezierPath(roundedRect: stampRect, cornerRadius: 10)
        UIColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 0.10).setFill()
        stampPath.fill()
        UIColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 0.75).setStroke()
        stampPath.lineWidth = 1.4
        stampPath.stroke()

        let stampAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: UIColor(red: 0.82, green: 0.12, blue: 0.12, alpha: 1.0)
        ]
        ("ĐÃ KÝ & ĐÓNG DẤU MẪU\nHRPARTNER BI" as NSString).draw(
            in: CGRect(x: 368, y: 458, width: 120, height: 38),
            withAttributes: stampAttr
        )

        drawPdfFooter(in: bounds, pageNumber: 2, totalPages: 2, author: bulletin.authorDisplay)
    }

    private static func drawPdfFooter(
        in bounds: CGRect,
        pageNumber: Int,
        totalPages: Int,
        author: String
    ) {
        let footerLine = UIBezierPath()
        footerLine.move(to: CGPoint(x: 42, y: bounds.height - 52))
        footerLine.addLine(to: CGPoint(x: bounds.width - 42, y: bounds.height - 52))
        UIColor(white: 0.85, alpha: 1.0).setStroke()
        footerLine.lineWidth = 0.8
        footerLine.stroke()

        let footerAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor(white: 0.45, alpha: 1.0)
        ]
        ("\(author) · Hệ thống HRP BI" as NSString).draw(
            at: CGPoint(x: 42, y: bounds.height - 40),
            withAttributes: footerAttr
        )
        ("Trang \(pageNumber) / \(totalPages)" as NSString).draw(
            at: CGPoint(x: bounds.width - 104, y: bounds.height - 40),
            withAttributes: footerAttr
        )
    }
}

// MARK: - HRPartner Bulletin Sheet (Bản tin HRPartner)

private struct BulletinPreviewImageSelection: Identifiable {
    let id: String
    let attachment: HrpBulletinAttachment
    let image: UIImage
}

private struct BulletinPreviewPdfSelection: Identifiable {
    let id: String
    let attachment: HrpBulletinAttachment
    let fileUrl: URL
}

public struct HrpBulletinSheet: View {
    @ObservedObject var viewModel: MiniBiViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBulletinId: String? = nil
    @State private var activeImagePreview: BulletinPreviewImageSelection? = nil
    @State private var activePdfPreview: BulletinPreviewPdfSelection? = nil

    public init(viewModel: MiniBiViewModel) {
        self.viewModel = viewModel
    }

    private var selectedItem: HrpBulletinItem? {
        guard let id = selectedBulletinId else { return nil }
        return viewModel.bulletinItems.first(where: { $0.id == id })
    }

    public var body: some View {
        let theme = viewModel.selectedTheme

        NavigationStack {
            Group {
                if let item = selectedItem {
                    bulletinDetailView(item: item, theme: theme)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    bulletinListView(theme: theme)
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.86), value: selectedBulletinId)
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Bản tin HRPartner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if selectedBulletinId != nil {
                        Button {
                            HapticsManager.selection()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                                selectedBulletinId = nil
                                viewModel.selectedBulletinDetailId = nil
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.caption.weight(.bold))
                                Text("Danh sách")
                            }
                        }
                    } else {
                        Button("Đóng") {
                            viewModel.selectedBulletinDetailId = nil
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if selectedBulletinId == nil && viewModel.unreadBulletinCount > 0 {
                        Button("Đọc tất cả") {
                            HapticsManager.selection()
                            viewModel.markAllBulletinsRead()
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .onAppear {
                if let targetId = viewModel.selectedBulletinDetailId, !targetId.isEmpty {
                    selectedBulletinId = targetId
                }
            }
            .onChange(of: viewModel.selectedBulletinDetailId) { newId in
                if let newId, !newId.isEmpty {
                    selectedBulletinId = newId
                }
            }
            .sheet(item: $activePdfPreview) { selection in
                HrpBulletinPdfReaderSheet(
                    attachment: selection.attachment,
                    fileUrl: selection.fileUrl,
                    theme: theme
                )
            }
            .fullScreenCover(item: $activeImagePreview) { selection in
                HrpBulletinImageLightboxSheet(
                    attachment: selection.attachment,
                    image: selection.image
                )
            }
        }
    }

    private func bulletinListView(theme: MiniBiThemePalette) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                // Category Filter Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(HrpBulletinCategory.filterCases) { category in
                            let isSelected = viewModel.selectedBulletinCategory == category
                            Button {
                                HapticsManager.selection()
                                withAnimation(.easeOut(duration: 0.18)) {
                                    viewModel.selectedBulletinCategory = category
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: category.iconName)
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(category.titleVi)
                                        .font(.caption.weight(isSelected ? .bold : .medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(isSelected ? theme.primary.opacity(0.14) : Color.white)
                                )
                                .foregroundColor(isSelected ? theme.primary : SemanticColors.textSecondary)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(isSelected ? theme.primary.opacity(0.75) : SemanticColors.borderSubtle, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }

                // Mockup Preview Notice Banner + Test New Bulletin Notification Button
                if !HrpBulletinContract.REMOTE_API_ENABLED {
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.caption.weight(.bold))
                            .foregroundColor(theme.primary)
                        Text("Bản tin nội bộ HRPartner (có đính kèm Ảnh, PDF 2 trang & báo tin mới).")
                            .font(.caption)
                            .foregroundColor(SemanticColors.textSecondary)
                        Spacer(minLength: 4)
                        Button {
                            HapticsManager.selection()
                            viewModel.triggerSampleBulletinNotification()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "bell.badge.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Báo thử")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(theme.primary)
                            )
                            .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: HrpDesignTokens.radiusMD, style: .continuous)
                            .fill(theme.primaryLight.opacity(0.7))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: HrpDesignTokens.radiusMD, style: .continuous)
                            .stroke(theme.primary.opacity(0.22), lineWidth: 0.8)
                    )
                }

                let items = viewModel.filteredBulletinItems
                if items.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "newspaper")
                            .font(.system(size: 34))
                            .foregroundColor(theme.primary.opacity(0.6))
                        Text("Chưa có bản tin nào trong mục này.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(SemanticColors.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .hrpCardSurface(cornerRadius: HrpDesignTokens.radiusCard)
                } else {
                    ForEach(items) { item in
                        bulletinRowCard(item: item, theme: theme)
                    }
                }
            }
            .padding(14)
        }
    }

    private func bulletinRowCard(item: HrpBulletinItem, theme: MiniBiThemePalette) -> some View {
        let iconTint = categoryAccentColor(for: item.category, theme: theme)

        return Button {
            HapticsManager.selection()
            viewModel.markBulletinRead(item.id)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                selectedBulletinId = item.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    ZStack(alignment: .topTrailing) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(iconTint.opacity(0.12))
                            .frame(width: 38, height: 38)
                        Image(systemName: item.category.iconName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(iconTint)
                            .frame(width: 38, height: 38)

                        if !item.isRead {
                            Circle()
                                .fill(theme.primary)
                                .frame(width: 8, height: 8)
                                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                                .offset(x: 2, y: -2)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(item.categoryDisplay)
                                .font(.caption2.weight(.bold))
                                .foregroundColor(iconTint)

                            Text("·")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(SemanticColors.textMuted)

                            Text(item.publishedDateDisplay)
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(SemanticColors.textSecondary)

                            Spacer(minLength: 4)

                            if let badge = item.badgeText, !badge.isEmpty {
                                Text(badge)
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2.5)
                                    .background(
                                        Capsule(style: .continuous)
                                            .fill(iconTint.opacity(0.14))
                                    )
                                    .foregroundColor(iconTint)
                            }
                        }

                        Text(item.title)
                            .font(.subheadline.weight(item.isRead ? .semibold : .bold))
                            .foregroundColor(SemanticColors.textPrimary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text(item.summary)
                    .font(.caption)
                    .foregroundColor(SemanticColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                // Attachment Badges (IMAGE + PDF)
                if item.attachmentSummary.hasAttachments {
                    HStack(spacing: 8) {
                        if item.attachmentSummary.pdfCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.richtext.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("\(item.attachmentSummary.pdfCount) tệp PDF")
                                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color(hex: 0xDC2626).opacity(0.10))
                            )
                            .foregroundColor(Color(hex: 0xDC2626))
                        }

                        if item.attachmentSummary.imageCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("\(item.attachmentSummary.imageCount) hình ảnh")
                                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(iconTint.opacity(0.10))
                            )
                            .foregroundColor(iconTint)
                        }

                        Spacer(minLength: 0)
                    }
                }

                HStack {
                    Text(item.authorDisplay)
                        .font(.caption2)
                        .foregroundColor(SemanticColors.textMuted)
                    Spacer()
                    HStack(spacing: 3) {
                        Text(item.isRead ? "Đã xem · Mở lại" : "Xem chi tiết")
                            .font(.caption2.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(theme.primary)
                }
            }
            .padding(14)
            .hrpCardSurface(
                cornerRadius: HrpDesignTokens.radiusCard,
                borderColor: !item.isRead ? theme.primary.opacity(0.34) : SemanticColors.borderSubtle.opacity(0.85)
            )
        }
        .buttonStyle(HrpPressableButtonStyle())
    }

    private func bulletinDetailView(item: HrpBulletinItem, theme: MiniBiThemePalette) -> some View {
        let iconTint = categoryAccentColor(for: item.category, theme: theme)

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Main Article Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        HStack(spacing: 5) {
                            Image(systemName: item.category.iconName)
                                .font(.system(size: 11, weight: .semibold))
                            Text(item.categoryDisplay)
                                .font(.caption2.weight(.bold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(iconTint.opacity(0.14))
                        )
                        .foregroundColor(iconTint)

                        Text("Ngày đăng: \(item.publishedDateDisplay)")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(SemanticColors.textSecondary)

                        Spacer()

                        if item.isRead {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                Text("Đã xem")
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundColor(SemanticColors.successText)
                        }
                    }

                    Text(item.title)
                        .font(.title3.weight(.bold))
                        .foregroundColor(SemanticColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.authorDisplay)
                        .font(.caption.weight(.medium))
                        .foregroundColor(SemanticColors.textMuted)

                    Divider()

                    Text(item.summary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(SemanticColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(item.contentSections.enumerated()), id: \.offset) { _, paragraph in
                            Text(paragraph)
                                .font(.subheadline)
                                .foregroundColor(SemanticColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: HrpDesignTokens.radiusMD, style: .continuous)
                                        .fill(SemanticColors.surfaceMuted)
                                )
                        }
                    }
                }
                .padding(16)
                .hrpCardSurface(cornerRadius: HrpDesignTokens.radiusCard)

                // Image Attachments Section (Tap to open Fullscreen Pinch-to-Zoom Lightbox)
                if !item.imageAttachments.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(iconTint)
                            Text("Hình ảnh đính kèm (\(item.imageAttachments.count))")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(SemanticColors.textPrimary)
                            Spacer()
                            Text("Chạm để phóng to")
                                .font(.caption2)
                                .foregroundColor(SemanticColors.textMuted)
                        }

                        ForEach(item.imageAttachments) { attachment in
                            let uiImage = HrpBulletinMockupMediaGenerator.sampleImage(for: attachment, bulletin: item)
                            Button {
                                HapticsManager.selection()
                                activeImagePreview = BulletinPreviewImageSelection(
                                    id: attachment.id,
                                    attachment: attachment,
                                    image: uiImage
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    ZStack(alignment: .bottomTrailing) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFit()
                                            .clipShape(RoundedRectangle(cornerRadius: HrpDesignTokens.radiusMD, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: HrpDesignTokens.radiusMD, style: .continuous)
                                                    .stroke(SemanticColors.borderSubtle, lineWidth: 0.8)
                                            )

                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                                .font(.system(size: 10, weight: .bold))
                                            Text("Phóng to")
                                                .font(.caption2.weight(.bold))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.black.opacity(0.68))
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                        .padding(8)
                                    }

                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(attachment.title)
                                                .font(.caption.weight(.bold))
                                                .foregroundColor(SemanticColors.textPrimary)
                                                .multilineTextAlignment(.leading)
                                            Text(attachment.metadataSubtitle)
                                                .font(.caption2.monospacedDigit())
                                                .foregroundColor(SemanticColors.textSecondary)
                                        }
                                        Spacer()
                                    }
                                }
                            }
                            .buttonStyle(HrpPressableButtonStyle())
                        }
                    }
                    .padding(14)
                    .hrpCardSurface(cornerRadius: HrpDesignTokens.radiusCard)
                }

                // PDF Attachments Section (Tap to open Native PDFKit 2-Page Reader)
                if !item.pdfAttachments.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.richtext.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(Color(hex: 0xDC2626))
                            Text("Văn bản PDF đính kèm (\(item.pdfAttachments.count))")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(SemanticColors.textPrimary)
                            Spacer()
                        }

                        ForEach(item.pdfAttachments) { attachment in
                            let pdfUrl = HrpBulletinMockupMediaGenerator.samplePdfUrl(for: attachment, bulletin: item)
                            Button {
                                HapticsManager.selection()
                                activePdfPreview = BulletinPreviewPdfSelection(
                                    id: attachment.id,
                                    attachment: attachment,
                                    fileUrl: pdfUrl
                                )
                            } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color(hex: 0xDC2626).opacity(0.12))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "doc.text.fill")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(Color(hex: 0xDC2626))
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(attachment.title)
                                            .font(.caption.weight(.bold))
                                            .foregroundColor(SemanticColors.textPrimary)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)

                                        Text(attachment.fileName)
                                            .font(.caption2)
                                            .foregroundColor(SemanticColors.textSecondary)
                                            .lineLimit(1)

                                        Text(attachment.metadataSubtitle)
                                            .font(.caption2.weight(.semibold).monospacedDigit())
                                            .foregroundColor(Color(hex: 0xDC2626))
                                    }

                                    Spacer(minLength: 6)

                                    HStack(spacing: 4) {
                                        Text("Đọc PDF")
                                            .font(.caption.weight(.bold))
                                        Image(systemName: "arrow.up.right.square.fill")
                                            .font(.caption.weight(.bold))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(
                                        RoundedRectangle(cornerRadius: HrpDesignTokens.radiusXS, style: .continuous)
                                            .fill(theme.primary)
                                    )
                                    .foregroundColor(.white)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: HrpDesignTokens.radiusMD, style: .continuous)
                                        .fill(SemanticColors.surfaceMuted)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: HrpDesignTokens.radiusMD, style: .continuous)
                                        .stroke(SemanticColors.borderSubtle, lineWidth: 0.8)
                                )
                            }
                            .buttonStyle(HrpPressableButtonStyle())
                        }
                    }
                    .padding(14)
                    .hrpCardSurface(cornerRadius: HrpDesignTokens.radiusCard)
                }
            }
            .padding(14)
        }
    }

    private func categoryAccentColor(for category: HrpBulletinCategory, theme: MiniBiThemePalette) -> Color {
        switch category {
        case .all, .hrNews, .general:
            return theme.primary
        case .holidaySchedule:
            return Color(hex: 0x0284C7)
        case .internalPolicy:
            return Color(hex: 0x15803D)
        }
    }
}

// MARK: - Native PDFKit Reader Sheet (2-Page Multi-Page Viewer + ShareLink)

private struct HrpBulletinPdfReaderSheet: View {
    let attachment: HrpBulletinAttachment
    let fileUrl: URL
    let theme: MiniBiThemePalette
    @Environment(\.dismiss) private var dismiss
    @State private var currentPageIndex: Int = 1
    @State private var totalPages: Int = 2

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HrpPdfKitRepresentableView(
                    fileUrl: fileUrl,
                    currentPageIndex: $currentPageIndex,
                    totalPages: $totalPages
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom Page Status Bar
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.richtext")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(theme.primary)
                        Text(attachment.fileName)
                            .font(.caption.weight(.medium))
                            .foregroundColor(SemanticColors.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text("Trang \(currentPageIndex) / \(max(1, totalPages))")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(theme.primaryLight)
                        )
                        .foregroundColor(theme.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white)
            }
            .navigationTitle(attachment.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(item: fileUrl) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Chia sẻ")
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
            }
        }
    }
}

private struct HrpPdfKitRepresentableView: UIViewRepresentable {
    let fileUrl: URL
    @Binding var currentPageIndex: Int
    @Binding var totalPages: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(false)
        pdfView.backgroundColor = UIColor(white: 0.93, alpha: 1.0)

        if let doc = PDFDocument(url: fileUrl) {
            pdfView.document = doc
            DispatchQueue.main.async {
                self.totalPages = max(1, doc.pageCount)
                self.currentPageIndex = 1
            }
        }

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handlePageChange(_:)),
            name: Notification.Name.PDFViewPageChanged,
            object: pdfView
        )
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document?.documentURL != fileUrl, let doc = PDFDocument(url: fileUrl) {
            pdfView.document = doc
            DispatchQueue.main.async {
                self.totalPages = max(1, doc.pageCount)
            }
        }
    }

    final class Coordinator: NSObject {
        let parent: HrpPdfKitRepresentableView

        init(parent: HrpPdfKitRepresentableView) {
            self.parent = parent
        }

        @objc func handlePageChange(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let doc = pdfView.document,
                  let currentPage = pdfView.currentPage else {
                return
            }
            let pageIdx = doc.index(for: currentPage) + 1
            let count = max(1, doc.pageCount)
            DispatchQueue.main.async {
                self.parent.currentPageIndex = pageIdx
                self.parent.totalPages = count
            }
        }
    }
}

// MARK: - Fullscreen Pinch-to-Zoom Image Lightbox Sheet (1x - 4x Zoom + Double Tap + Safe-Area Header & Controls)

private struct HrpBulletinImageLightboxSheet: View {
    let attachment: HrpBulletinAttachment
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var zoomScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            HrpZoomableImageScrollView(image: image, zoomScale: $zoomScale)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Safe-area respecting top header bar (never overlaps iOS clock or TestFlight indicator)
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(attachment.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text("\(attachment.metadataSubtitle) · Chụm 2 ngón hoặc chạm đúp để thu phóng")
                            .font(.caption2)
                            .foregroundColor(Color.white.opacity(0.78))
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        HapticsManager.selection()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.72))

                Spacer()

                // Bottom Zoom Control Pill (- / 100% / +)
                HStack(spacing: 18) {
                    Button {
                        HapticsManager.selection()
                        zoomScale = max(1.0, (zoomScale - 0.5))
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(zoomScale > 1.01 ? .white : Color.white.opacity(0.4))
                            .frame(width: 36, height: 36)
                    }
                    .disabled(zoomScale <= 1.01)

                    Button {
                        HapticsManager.selection()
                        zoomScale = 1.0
                    } label: {
                        Text("\(Int(round(zoomScale * 100)))%")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.18))
                            )
                    }

                    Button {
                        HapticsManager.selection()
                        zoomScale = min(4.0, (zoomScale + 0.5))
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(zoomScale < 3.99 ? .white : Color.white.opacity(0.4))
                            .frame(width: 36, height: 36)
                    }
                    .disabled(zoomScale >= 3.99)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.75))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.bottom, 16)
            }
        }
    }
}

public final class HrpCenteringZoomScrollView: UIScrollView, UIScrollViewDelegate {
    public let imageView = UIImageView()
    public var onZoomScaleChanged: ((CGFloat) -> Void)?
    private var lastLayoutBoundsSize: CGSize = .zero

    public init(image: UIImage) {
        super.init(frame: .zero)
        delegate = self
        minimumZoomScale = 1.0
        maximumZoomScale = 4.0
        bouncesZoom = true
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        backgroundColor = .black

        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }
        if lastLayoutBoundsSize != bounds.size {
            lastLayoutBoundsSize = bounds.size
            recalculateAspectFitFrameAndCenter()
        } else {
            centerContentWithinBounds()
        }
    }

    public func updateImageIfNeeded(_ newImage: UIImage) {
        if imageView.image !== newImage {
            imageView.image = newImage
            lastLayoutBoundsSize = .zero
            setNeedsLayout()
        }
    }

    public func recalculateAspectFitFrameAndCenter() {
        guard let img = imageView.image,
              img.size.width > 0,
              img.size.height > 0,
              bounds.width > 0,
              bounds.height > 0 else {
            return
        }
        zoomScale = 1.0
        imageView.transform = .identity

        let scale = min(bounds.width / img.size.width, bounds.height / img.size.height)
        let fittedSize = CGSize(
            width: max(1, floor(img.size.width * scale)),
            height: max(1, floor(img.size.height * scale))
        )
        imageView.frame = CGRect(origin: .zero, size: fittedSize)
        contentSize = fittedSize
        centerContentWithinBounds()
        contentOffset = CGPoint(x: -contentInset.left, y: -contentInset.top)
        onZoomScaleChanged?(1.0)
    }

    public func centerContentWithinBounds() {
        let offsetX = max((bounds.width - contentSize.width) * 0.5, 0)
        let offsetY = max((bounds.height - contentSize.height) * 0.5, 0)
        let targetInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
        if contentInset != targetInset {
            contentInset = targetInset
        }
    }

    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerContentWithinBounds()
        onZoomScaleChanged?(scrollView.zoomScale)
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        if zoomScale > 1.05 {
            setZoomScale(1.0, animated: true)
        } else {
            let targetScale: CGFloat = 2.5
            let tapPoint = recognizer.location(in: imageView)
            let zoomWidth = imageView.bounds.width / targetScale
            let zoomHeight = imageView.bounds.height / targetScale
            let zoomRect = CGRect(
                x: tapPoint.x - (zoomWidth * 0.5),
                y: tapPoint.y - (zoomHeight * 0.5),
                width: zoomWidth,
                height: zoomHeight
            )
            zoom(to: zoomRect, animated: true)
        }
    }
}

private struct HrpZoomableImageScrollView: UIViewRepresentable {
    let image: UIImage
    @Binding var zoomScale: CGFloat

    func makeUIView(context: Context) -> HrpCenteringZoomScrollView {
        let scrollView = HrpCenteringZoomScrollView(image: image)
        scrollView.onZoomScaleChanged = { newScale in
            DispatchQueue.main.async {
                if abs(self.zoomScale - newScale) > 0.01 {
                    self.zoomScale = newScale
                }
            }
        }
        return scrollView
    }

    func updateUIView(_ uiView: HrpCenteringZoomScrollView, context: Context) {
        uiView.updateImageIfNeeded(image)
        if abs(uiView.zoomScale - zoomScale) > 0.02 {
            uiView.setZoomScale(min(max(zoomScale, 1.0), 4.0), animated: true)
        }
    }
}

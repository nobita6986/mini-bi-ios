import SwiftUI

// MARK: - Dashboard Screen & CCCD Review Section
// Mirrors Android's `ui/screens/DashboardScreen.kt` & `ui/screens/CccdReviewSection.kt` 100%

public struct DashboardScreen: View {
    @ObservedObject var viewModel: MiniBiViewModel
    @Namespace private var dashboardTabNamespace

    public init(viewModel: MiniBiViewModel) {
        self.viewModel = viewModel
    }

    private var hasLoadedAnyOverviewData: Bool {
        viewModel.hasLoadedDashboardInSession
    }

    public var body: some View {
        let theme = viewModel.selectedTheme
        let activeTab: DashboardSubTab = DashboardSubTab.primaryTabs.contains(viewModel.selectedDashboardSubTab)
            ? viewModel.selectedDashboardSubTab
            : .overview

        VStack(spacing: 0) {
            // 1-row 50/50 Segmented Pill Bar (`Tổng quát` & `Theo nhóm`)
            HStack(spacing: 4) {
                ForEach(DashboardSubTab.primaryTabs) { tab in
                    let isSelected = activeTab == tab
                    Button {
                        KeyboardDismissal.dismiss()
                        if !isSelected {
                            HapticsManager.selection()
                        }
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
                            viewModel.selectedDashboardSubTab = tab
                        }
                    } label: {
                        Text(tab.titleVi)
                            .font(.subheadline.weight(isSelected ? .semibold : .medium))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.white)
                                        .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)
                                        .matchedGeometryEffect(id: "dashboard_subtab_pill", in: dashboardTabNamespace)
                                } else {
                                    Color.clear
                                }
                            }
                            .foregroundColor(isSelected ? theme.primary : SemanticColors.textSecondary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: 0xF1F5F9))
            )
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background(Color.white)

            // Date & Scope Filter Bar
            dateAndScopeFilterBar

            Rectangle()
                .fill(SemanticColors.borderSubtle.opacity(0.65))
                .frame(height: 0.5)

            // Tab Content
            ScrollView {
                VStack(spacing: 14) {
                    if !viewModel.dashboardErrorMessage.isEmpty && !viewModel.isLoadingDashboard {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(SemanticColors.dangerText)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Không thể tải dữ liệu báo cáo")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(SemanticColors.dangerText)
                                Text(viewModel.dashboardErrorMessage)
                                    .font(.caption)
                                    .foregroundColor(SemanticColors.textSecondary)
                            }
                            Spacer()
                            Button("Thử lại") {
                                HapticsManager.lightImpact()
                                viewModel.resetDashboardDisplayForFilterChange()
                                Task { await viewModel.loadDashboardData(includeCccdTabs: false, force: true) }
                            }
                            .font(.caption.weight(.bold))
                            .foregroundColor(theme.primary)
                            .frame(minHeight: 36)
                            .contentShape(Rectangle())
                        }
                        .padding(12)
                        .background(SemanticColors.dangerBg)
                        .clipShape(RoundedRectangle(cornerRadius: HrpDesignTokens.radiusMD, style: .continuous))
                    }

                    if viewModel.isLoadingDashboard && !hasLoadedAnyOverviewData {
                        dashboardSkeletonPlaceholder(theme: theme, activeTab: activeTab)
                    } else if activeTab == .teamReport {
                        teamReportSection(theme: theme)
                    } else {
                        overviewSection(theme: theme)
                    }
                }
                .padding(14)
            }
            .refreshable {
                await viewModel.performRefreshable {
                    await viewModel.loadDashboardData(force: true)
                }
            }
        }
        .background(theme.background)
        .dismissKeyboardOnTapOutside()
        .onAppear {
            viewModel.normalizeSelectedDashboardSubTab()
            if viewModel.dashboardScope != "all" {
                viewModel.dashboardScope = "all"
            }
            if viewModel.isAuthenticated
                && !viewModel.isLoadingDashboard
                && !viewModel.hasLoadedDashboardInSession {
                Task { await viewModel.loadDashboardData(includeCccdTabs: false) }
            }
        }
    }

    // MARK: - Skeleton Placeholder (Perceived Performance Law #1)

    private func dashboardSkeletonPlaceholder(theme: MiniBiThemePalette, activeTab: DashboardSubTab) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Báo cáo tổng quát tuyển dụng")
                    .font(.headline)
                Text("Ngày dữ liệu: 12/11/2026 · Phạm vi: Toàn hệ thống")
                    .font(.caption)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(0..<4, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TỔNG HỒ SƠ")
                                .font(.caption2.weight(.bold))
                            Text("1.280 NLĐ")
                                .font(.title3.weight(.heavy))
                            Text("18 dự án · 24 người tuyển")
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .hrpMutedTile(cornerRadius: HrpDesignTokens.radiusMD)
                    }
                }
            }
            .padding(14)
            .hrpCardSurface(cornerRadius: HrpDesignTokens.radiusCard)

            VStack(alignment: .leading, spacing: 10) {
                Text(activeTab == .teamReport ? "Đóng góp của thành viên nhóm" : "Tỷ trọng theo người tuyển")
                    .font(.headline)
                ForEach(0..<4, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Nguyễn Văn Tuyển Dụng")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("33 NLĐ (14.2%)")
                                .font(.caption.weight(.bold))
                        }
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.primary.opacity(0.25))
                            .frame(height: 6)
                    }
                    .padding(10)
                    .hrpMutedTile(cornerRadius: HrpDesignTokens.radiusMD)
                }
            }
            .padding(14)
            .hrpCardSurface(cornerRadius: HrpDesignTokens.radiusCard)
        }
        .redacted(reason: .placeholder)
    }

    // MARK: - Date Filter Bar (Full-Width Period Chips)

    private var dateAndScopeFilterBar: some View {
        let theme = viewModel.selectedTheme
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DateFilterPreset.allCases) { preset in
                    let selected = viewModel.selectedDatePreset == preset
                    Button {
                        KeyboardDismissal.dismiss()
                        HapticsManager.selection()
                        viewModel.applyDatePreset(preset, reload: true)
                    } label: {
                        Text(preset.titleVi)
                            .font(.caption.weight(selected ? .bold : .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .frame(minHeight: 32)
                            .background(selected ? theme.primaryLight : SemanticColors.surfaceMuted)
                            .foregroundColor(selected ? theme.primary : SemanticColors.textSecondary)
                            .overlay(
                                Capsule()
                                    .stroke(selected ? theme.primary.opacity(0.35) : Color.clear, lineWidth: 1)
                            )
                            .clipShape(Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.vertical, 8)
        .background(Color.white)
    }

    // MARK: - 1. Overview Section (`GeneralOverviewSection`)

    @ViewBuilder
    private func overviewSection(theme: MiniBiThemePalette) -> some View {
        let snapshot = viewModel.generalOverviewSnapshot ?? fallbackOverviewSnapshotFromLegacy()
        GeneralOverviewSection(
            snapshot: snapshot,
            theme: theme
        )
    }

    private func fallbackOverviewSnapshotFromLegacy() -> GeneralOverviewSnapshot {
        let kpis = viewModel.generalOverview.kpis
        let isPeriodFiltered = viewModel.selectedDatePreset != .all
        let workingRate: Double? = kpis.totalHeadcount > 0
            ? (Double(kpis.activeCount) * 100.0 / Double(kpis.totalHeadcount))
            : nil
        return GeneralOverviewSnapshot(
            asOfDate: LeaveContract.todayVietnamIsoDate(),
            scopeDescription: "Toàn hệ thống",
            totalProfiles: kpis.totalHeadcount,
            workingCount: kpis.activeCount,
            waitingCount: kpis.interviewCount,
            leftCount: kpis.inactiveCount,
            audienceKind: "all",
            isPeriodFiltered: isPeriodFiltered,
            workingRatePct: workingRate,
            projectCount: max(viewModel.generalOverview.projectsTotal, viewModel.generalOverview.projects.count),
            recruiterCount: viewModel.generalOverview.recruiters.count,
            periodFromDate: isPeriodFiltered ? viewModel.filterStartDate : nil,
            periodToDate: isPeriodFiltered ? viewModel.filterEndDate : nil
        )
    }

    // MARK: - 2. Team Report Section (`TeamBucketPickerCard` + `TeamReportDetailCard`)

    @ViewBuilder
    private func teamReportSection(theme: MiniBiThemePalette) -> some View {
        if !viewModel.canViewTeamReport {
            VStack(spacing: 10) {
                Image(systemName: "person.2.slash.fill")
                    .font(.title2)
                    .foregroundColor(SemanticColors.textMuted)
                Text("Tài khoản hiện tại không quản lý nhóm tuyển dụng. Vui lòng xem số liệu cá nhân tại tab Tổng quát.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(SemanticColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .hrpCardSurface(cornerRadius: HrpDesignTokens.radiusCard)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                if viewModel.teamScopeOptions.count > 1 {
                    TeamBucketPickerCard(
                        options: viewModel.teamScopeOptions,
                        selectedKey: viewModel.selectedTeamBucketKey,
                        theme: theme
                    ) { bucketKey in
                        HapticsManager.selection()
                        Task { await viewModel.loadTeamReport(bucketKey) }
                    }
                }

                if let teamErr = viewModel.teamReportErrorMessage, !teamErr.isEmpty, !viewModel.isLoadingTeamReport {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(SemanticColors.dangerText)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Không tải được báo cáo nhóm")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(SemanticColors.dangerText)
                            Text(teamErr)
                                .font(.caption)
                                .foregroundColor(SemanticColors.textSecondary)
                        }
                        Spacer()
                        if let key = viewModel.selectedTeamBucketKey {
                            Button("Thử lại") {
                                HapticsManager.lightImpact()
                                Task { await viewModel.loadTeamReport(key) }
                            }
                            .font(.caption.weight(.bold))
                            .foregroundColor(theme.primary)
                        }
                    }
                    .padding(12)
                    .background(SemanticColors.dangerBg)
                    .clipShape(RoundedRectangle(cornerRadius: HrpDesignTokens.radiusMD, style: .continuous))
                }

                if viewModel.isLoadingTeamReport && viewModel.selectedTeamReport == nil {
                    dashboardSkeletonPlaceholder(theme: theme, activeTab: .teamReport)
                } else if let snapshot = viewModel.selectedTeamReport {
                    TeamReportDetailCard(
                        snapshot: snapshot,
                        isPeriodFiltered: viewModel.selectedDatePreset != .all,
                        isLoadingMoreDrillDown: viewModel.isLoadingMoreTeamDrillDown,
                        theme: theme
                    ) {
                        Task { await viewModel.loadMoreTeamDrillDown() }
                    }
                    .id(snapshot.bucketKey)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "person.3.fill")
                            .font(.largeTitle)
                            .foregroundColor(SemanticColors.textMuted)
                        Text("Chưa có dữ liệu báo cáo theo nhóm.")
                            .font(.subheadline)
                            .foregroundColor(SemanticColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .hrpCardSurface(cornerRadius: HrpDesignTokens.radiusCard)
                }
            }
        }
    }
}

// MARK: - Formatting Helpers for Dashboard Reporting

private enum DashboardFormatters {
    static func formatDateVi(_ raw: String?) -> String {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "—" }
        let prefix10 = String(trimmed.prefix(10))
        let parts = prefix10.split(separator: "-")
        if parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2 {
            return "\(parts[2])/\(parts[1])/\(parts[0])"
        }
        return prefix10
    }

    static func formatPct(_ pct: Double?) -> String {
        guard let pct else { return "0.0%" }
        return String(format: "%.1f%%", pct)
    }

    static func formatDecimalOne(_ value: Double?) -> String {
        guard let value else { return "0" }
        if abs(value.rounded() - value) < 0.05 {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.1f", value)
    }

    static func formatSigned(_ value: Int) -> String {
        if value > 0 { return "+\(value)" }
        return "\(value)"
    }
}

// MARK: - 1. GeneralOverviewSection (`Tổng quát`)

private struct GeneralOverviewSection: View {
    let snapshot: GeneralOverviewSnapshot
    let theme: MiniBiThemePalette

    private var headerSubtitle: String {
        let scopeText = snapshot.scopeDescription.isEmpty ? "Toàn hệ thống" : snapshot.scopeDescription
        if snapshot.isPeriodFiltered,
           let from = snapshot.periodFromDate, !from.isEmpty,
           let to = snapshot.periodToDate, !to.isEmpty {
            return "Kỳ lọc: \(DashboardFormatters.formatDateVi(from)) - \(DashboardFormatters.formatDateVi(to)) · Phạm vi: \(scopeText)"
        }
        let dateText = snapshot.asOfDate.isEmpty
            ? DashboardFormatters.formatDateVi(LeaveContract.todayVietnamIsoDate())
            : DashboardFormatters.formatDateVi(snapshot.asOfDate)
        return "Ngày dữ liệu: \(dateText) · Phạm vi: \(scopeText)"
    }

    private var nonPeriodTotalSubtitle: String {
        var scopeParts: [String] = []
        if let teamTotal = snapshot.teamTotal {
            scopeParts.append("Nhóm: \(teamTotal)")
        }
        if let managedTotal = snapshot.managedTotal {
            scopeParts.append("QLDA: \(managedTotal)")
        }
        if let recruitedTotal = snapshot.recruitedTotal {
            scopeParts.append("Tôi tuyển: \(recruitedTotal)")
        }
        if !scopeParts.isEmpty {
            return scopeParts.joined(separator: " · ")
        }
        return "\(snapshot.projectCount) dự án · \(snapshot.recruiterCount) người tuyển"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Main Summary Card
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Báo cáo tổng quát tuyển dụng")
                        .font(.headline)
                        .foregroundColor(SemanticColors.textPrimary)
                    Text(headerSubtitle)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(SemanticColors.textSecondary)
                }

                // 2x2 KPI Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    if snapshot.isPeriodFiltered && snapshot.audienceKind == "all" {
                        overviewMetricTile(
                            label: "TUYỂN MỚI TRONG KỲ",
                            value: "\(snapshot.totalProfiles) NLĐ",
                            subtitle: "\(snapshot.projectCount) dự án · \(snapshot.recruiterCount) người tuyển",
                            accentColor: theme.primary
                        )
                        overviewMetricTile(
                            label: "VÀO LÀM TRONG KỲ",
                            value: "\(snapshot.workingCount) NLĐ",
                            subtitle: {
                                let closingW = snapshot.closingWorkingCount ?? snapshot.workingCount
                                let rateStr = DashboardFormatters.formatPct(snapshot.workingRatePct)
                                return "Đang làm cuối kỳ: \(closingW) (\(rateStr))"
                            }(),
                            accentColor: SemanticColors.successText
                        )
                        overviewMetricTile(
                            label: "CHỜ VIỆC TRONG KỲ",
                            value: "\(snapshot.waitingCount) NLĐ",
                            subtitle: "Chờ việc cuối kỳ: \(snapshot.closingWaitingCount ?? snapshot.waitingCount) NLĐ",
                            accentColor: SemanticColors.warningText
                        )
                        overviewMetricTile(
                            label: "NGHỈ VIỆC TRONG KỲ",
                            value: "\(snapshot.leftCount) NLĐ",
                            subtitle: {
                                let net = snapshot.periodNetOnChange ?? (snapshot.workingCount - snapshot.leftCount)
                                return "Biến động đang làm: \(DashboardFormatters.formatSigned(net)) NLĐ"
                            }(),
                            accentColor: SemanticColors.dangerText
                        )
                    } else {
                        overviewMetricTile(
                            label: "TỔNG HỒ SƠ",
                            value: "\(snapshot.totalProfiles) NLĐ",
                            subtitle: nonPeriodTotalSubtitle,
                            accentColor: theme.primary
                        )
                        overviewMetricTile(
                            label: "ĐANG LÀM",
                            value: "\(snapshot.workingCount) NLĐ",
                            subtitle: "Tỷ lệ đang làm: \(DashboardFormatters.formatPct(snapshot.workingRatePct))",
                            accentColor: SemanticColors.successText,
                            badgePill: true
                        )
                        overviewMetricTile(
                            label: "ĐANG CHỜ VIỆC",
                            value: "\(snapshot.waitingCount) NLĐ",
                            subtitle: "\(snapshot.projectCount) dự án có nhân sự",
                            accentColor: SemanticColors.warningText
                        )
                        overviewMetricTile(
                            label: "ĐÃ NGHỈ",
                            value: "\(snapshot.leftCount) NLĐ",
                            subtitle: snapshot.retention7dPct != nil
                                ? "Giữ chân 7 ngày: \(DashboardFormatters.formatPct(snapshot.retention7dPct))"
                                : "\(snapshot.recruiterCount) người tuyển",
                            accentColor: SemanticColors.dangerText
                        )
                    }
                }

                // Period Balance Banner when periodNewEpisodes is present on non-all/general view
                if !(snapshot.isPeriodFiltered && snapshot.audienceKind == "all"),
                   let newEp = snapshot.periodNewEpisodes {
                    let fromVi = DashboardFormatters.formatDateVi(snapshot.periodFromDate)
                    let toVi = DashboardFormatters.formatDateVi(snapshot.periodToDate)
                    let onIn = snapshot.periodOnInflow ?? snapshot.workingCount
                    let offIn = snapshot.periodOffInflow ?? snapshot.leftCount
                    let net = snapshot.periodNetOnChange ?? (onIn - offIn)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Biến động trong kỳ (\(fromVi) – \(toVi))")
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundColor(theme.primary)
                        Text("Tuyển mới: \(newEp) · Vào làm: \(onIn) · Nghỉ việc: \(offIn) · Tăng/giảm: \(DashboardFormatters.formatSigned(net))")
                            .font(.caption2.weight(.medium))
                            .monospacedDigit()
                            .foregroundColor(SemanticColors.textSecondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.primaryLight.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: HrpDesignTokens.radiusMD, style: .continuous))
                }

                // 3-column Hiring Pace Strip when activeHiringDays > 0
                if snapshot.activeHiringDays > 0 {
                    HiringPaceStripView(
                        activeHiringDays: snapshot.activeHiringDays,
                        avgPerActiveDay: snapshot.avgPerActiveDay,
                        peakDailyCount: snapshot.peakDailyCount,
                        peakDateIso: snapshot.peakDateIso,
                        theme: theme
                    )
                }
            }
            .padding(14)
            .hrpCardSurface(cornerRadius: HrpDesignTokens.radiusCard)

            // 1. Tỷ trọng theo người tuyển / Đóng góp thành viên nhóm
            if !snapshot.byRecruiter.isEmpty {
                BucketBreakdownCard(
                    title: snapshot.audienceKind == "team" ? "Đóng góp thành viên nhóm" : "Tỷ trọng theo người tuyển",
                    subtitle: "Phân bổ theo số lượng hồ sơ ghi nhận",
                    items: snapshot.byRecruiter,
                    theme: theme
                )
            }

            // 2. Tỷ trọng theo dự án
            if !snapshot.byProject.isEmpty {
                let leadSub: String? = {
                    guard let lead = snapshot.leadingProject ?? snapshot.byProject.first else { return nil }
                    return "Dự án dẫn đầu: \(lead.display) (\(lead.count) NLĐ · \(DashboardFormatters.formatPct(lead.sharePct)))"
                }()
                BucketBreakdownCard(
                    title: "Tỷ trọng theo dự án",
                    subtitle: leadSub,
                    items: snapshot.byProject,
                    theme: theme
                )
            }

            // 3. Cơ cấu theo nhóm tuyển dụng / Cơ cấu theo loại hình lao động
            if !snapshot.bySecondaryGroup.isEmpty {
                BucketBreakdownCard(
                    title: snapshot.secondaryGroupTitle.isEmpty ? "Cơ cấu theo nhóm tuyển dụng" : snapshot.secondaryGroupTitle,
                    subtitle: nil,
                    items: snapshot.bySecondaryGroup,
                    theme: theme
                )
            }

            // 4. Cơ cấu nguồn tuyển (HRP / Vendor)
            if !snapshot.byProvider.isEmpty {
                BucketBreakdownCard(
                    title: "Cơ cấu nguồn tuyển (HRP / Vendor)",
                    subtitle: nil,
                    items: snapshot.byProvider,
                    theme: theme
                )
            }
        }
    }

    private func overviewMetricTile(
        label: String,
        value: String,
        subtitle: String,
        accentColor: Color,
        badgePill: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundColor(SemanticColors.textSecondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundColor(accentColor)
                .lineLimit(1)
            if badgePill {
                Text(subtitle)
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(SemanticColors.successBg)
                    .foregroundColor(SemanticColors.successText)
                    .clipShape(Capsule())
                    .lineLimit(1)
            } else {
                Text(subtitle)
                    .font(.caption2.weight(.medium))
                    .monospacedDigit()
                    .foregroundColor(SemanticColors.textMuted)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
        .padding(12)
        .hrpMutedTile(cornerRadius: HrpDesignTokens.radiusMD)
    }
}

// MARK: - 3-Column Hiring Pace Strip

private struct HiringPaceStripView: View {
    let activeHiringDays: Int
    let avgPerActiveDay: Double?
    let peakDailyCount: Int?
    let peakDateIso: String?
    let theme: MiniBiThemePalette

    var body: some View {
        HStack(spacing: 8) {
            paceCell(
                title: "Ngày có tuyển",
                value: "\(activeHiringDays) ngày",
                sub: nil
            )
            paceCell(
                title: "TB / ngày có số",
                value: "\(DashboardFormatters.formatDecimalOne(avgPerActiveDay)) NLĐ",
                sub: nil
            )
            paceCell(
                title: "Đỉnh / ngày",
                value: "\(peakDailyCount ?? 0) NLĐ",
                sub: (peakDateIso?.isEmpty == false) ? DashboardFormatters.formatDateVi(peakDateIso) : nil
            )
        }
    }

    private func paceCell(title: String, value: String, sub: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundColor(SemanticColors.textSecondary)
                .lineLimit(1)
            Text(value)
                .font(.footnote.weight(.bold))
                .monospacedDigit()
                .foregroundColor(theme.primary)
                .lineLimit(1)
            if let sub, !sub.isEmpty {
                Text(sub)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundColor(SemanticColors.textMuted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(Color(hex: 0xF8FAFC))
        .clipShape(RoundedRectangle(cornerRadius: HrpDesignTokens.radiusXS, style: .continuous))
    }
}

// MARK: - BucketBreakdownCard (`<Tên mục>` — `<count> NLĐ (<sharePct>%)` + 6pt bar)

private struct BucketBreakdownCard: View {
    let title: String
    let subtitle: String?
    let items: [BiBucketItem]
    let theme: MiniBiThemePalette
    @State private var visibleCount: Int = 10

    var body: some View {
        let visibleItems = Array(items.prefix(visibleCount))
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(SemanticColors.textPrimary)
                    Spacer()
                    Text("\(items.count) mục")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundColor(SemanticColors.textMuted)
                }
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(SemanticColors.textSecondary)
                }
            }

            LazyVStack(spacing: 8) {
                ForEach(visibleItems) { item in
                    let clampedRatio = min(1.0, max(0.0, item.sharePct / 100.0))
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(item.display)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(SemanticColors.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(item.count) NLĐ (\(DashboardFormatters.formatPct(item.sharePct)))")
                                .font(.caption.weight(.bold))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                                .foregroundColor(theme.primary)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(Color(hex: 0xE2E8F0))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(theme.primary)
                                    .frame(
                                        width: max(item.count > 0 ? 4 : 0, geo.size.width * clampedRatio),
                                        height: 6
                                    )
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding(10)
                    .hrpMutedTile(cornerRadius: HrpDesignTokens.radiusMD)
                }
            }

            if items.count > visibleCount {
                HrpLoadMoreButton(
                    title: "Xem thêm (\(items.count - visibleCount) mục)",
                    loadedCount: visibleItems.count,
                    totalCount: items.count,
                    isLoading: false,
                    theme: theme
                ) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        visibleCount += 15
                    }
                }
            }
        }
        .padding(14)
        .hrpCardSurface(cornerRadius: HrpDesignTokens.radiusCard)
    }
}

// MARK: - 2. TeamBucketPickerCard & TeamReportDetailCard (`Theo nhóm`)

private struct TeamBucketPickerCard: View {
    let options: [BiBucketItem]
    let selectedKey: String?
    let theme: MiniBiThemePalette
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Chọn nhóm tuyển dụng")
                .font(.subheadline.weight(.bold))
                .foregroundColor(SemanticColors.textPrimary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), spacing: 8)], spacing: 8) {
                ForEach(options) { bucket in
                    let isSelected = selectedKey?.caseInsensitiveCompare(bucket.key) == .orderedSame
                    let chipTitle = bucket.count > 0
                        ? "\(bucket.display) (\(bucket.count))"
                        : bucket.display
                    Button {
                        onSelect(bucket.key)
                    } label: {
                        Text(chipTitle)
                            .font(.caption.weight(isSelected ? .bold : .medium))
                            .monospacedDigit()
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(isSelected ? theme.primary : SemanticColors.surfaceMuted)
                            .foregroundColor(isSelected ? .white : SemanticColors.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: HrpDesignTokens.radiusXS, style: .continuous))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .hrpCardSurface(cornerRadius: HrpDesignTokens.radiusCard)
    }
}

private struct TeamReportDetailCard: View {
    let snapshot: TeamReportSnapshot
    let isPeriodFiltered: Bool
    let isLoadingMoreDrillDown: Bool
    let theme: MiniBiThemePalette
    let onLoadMoreFromServer: () -> Void
    @State private var visibleDetailCount: Int = 20

    private var totalRecruitedSubtitle: String {
        if let working = snapshot.workingCount, !isPeriodFiltered {
            let waiting = snapshot.waitingCount ?? 0
            let left = snapshot.leftCount ?? 0
            return "Đang làm: \(working) · Chờ: \(waiting) · Nghỉ: \(left)"
        }
        return "Tổng nhân sự tuyển ghi nhận của nhóm"
    }

    private var avgPerActiveDaySubtitle: String {
        if snapshot.activeHiringDays > 0 {
            if let peak = snapshot.peakDailyCount {
                return "\(snapshot.activeHiringDays) ngày có tuyển · Đỉnh: \(peak)"
            }
            return "\(snapshot.activeHiringDays) ngày có tuyển"
        }
        return "Chưa phát sinh ngày tuyển"
    }

    var body: some View {
        let visibleRows = Array(snapshot.rows.prefix(visibleDetailCount))

        VStack(alignment: .leading, spacing: 14) {
            // Team Header + 2x2 KPI Grid Card
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(theme.primaryLight)
                            .frame(width: 36, height: 36)
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(theme.primary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snapshot.bucketDisplay)
                            .font(.headline)
                            .foregroundColor(SemanticColors.textPrimary)
                        Text("Báo cáo hiệu suất nhóm tuyển dụng")
                            .font(.caption)
                            .foregroundColor(SemanticColors.textSecondary)
                    }
                    Spacer()
                    Text("\(snapshot.totalRecruited) NLĐ")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(theme.primaryLight)
                        .foregroundColor(theme.primary)
                        .clipShape(Capsule())
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    teamKpiTile(
                        label: "TỔNG TUYỂN NHÓM",
                        value: "\(snapshot.totalRecruited) NLĐ",
                        subtitle: totalRecruitedSubtitle,
                        accentColor: theme.primary
                    )
                    teamKpiTile(
                        label: "THÀNH VIÊN CÓ SỐ",
                        value: "\(snapshot.activeRecruiterCount) người",
                        subtitle: "Có phát sinh tuyển dụng",
                        accentColor: SemanticColors.successText
                    )
                    teamKpiTile(
                        label: "DỰ ÁN THAM GIA",
                        value: "\(snapshot.activeProjectCount) dự án",
                        subtitle: "Có nhân sự của nhóm",
                        accentColor: SemanticColors.infoText
                    )
                    teamKpiTile(
                        label: "TB / NGÀY CÓ SỐ",
                        value: "\(DashboardFormatters.formatDecimalOne(snapshot.avgPerActiveDay)) NLĐ",
                        subtitle: avgPerActiveDaySubtitle,
                        accentColor: SemanticColors.warningText
                    )
                }
            }
            .padding(14)
            .hrpCardSurface(cornerRadius: HrpDesignTokens.radiusCard)

            // 1. Đóng góp của thành viên nhóm
            if !snapshot.byRecruiter.isEmpty {
                BucketBreakdownCard(
                    title: "Đóng góp của thành viên nhóm",
                    subtitle: "Xếp hạng theo số lượng NLĐ tuyển được trong nhóm",
                    items: snapshot.byRecruiter,
                    theme: theme
                )
            }

            // 2. Theo dự án trong nhóm
            if !snapshot.byProject.isEmpty {
                BucketBreakdownCard(
                    title: "Theo dự án trong nhóm",
                    subtitle: nil,
                    items: snapshot.byProject,
                    theme: theme
                )
            }

            // 3. Theo loại hình làm việc
            if !snapshot.byEmployment.isEmpty {
                BucketBreakdownCard(
                    title: "Theo loại hình làm việc",
                    subtitle: nil,
                    items: snapshot.byEmployment,
                    theme: theme
                )
            }

            // 4. Theo nguồn tuyển (HRP / Vendor)
            if !snapshot.byProvider.isEmpty {
                BucketBreakdownCard(
                    title: "Theo nguồn tuyển (HRP / Vendor)",
                    subtitle: nil,
                    items: snapshot.byProvider,
                    theme: theme
                )
            }

            // Chi tiết lượt tuyển trong nhóm
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Chi tiết lượt tuyển trong nhóm")
                        .font(.headline)
                        .foregroundColor(SemanticColors.textPrimary)
                    Spacer()
                    Text("\(snapshot.rows.count) dòng")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundColor(SemanticColors.textMuted)
                }

                if snapshot.rows.isEmpty {
                    Text("Chưa có lượt tuyển nào của nhóm trong phạm vi kỳ đang chọn.")
                        .font(.subheadline)
                        .foregroundColor(SemanticColors.textMuted)
                        .padding(.vertical, 8)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(visibleRows) { row in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(row.projectDisplay) · \(row.recruiterDisplay)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(SemanticColors.textPrimary)
                                    .lineLimit(1)
                                Text("Ngày \(DashboardFormatters.formatDateVi(row.businessDate)) · \(row.providerTypeDisplay) · \(row.employmentTypeDisplay) · SL: \(row.recruitedCount)")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundColor(SemanticColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .hrpMutedTile(cornerRadius: HrpDesignTokens.radiusMD)
                        }
                    }

                    if snapshot.rows.count > visibleDetailCount {
                        let remaining = snapshot.rows.count - visibleDetailCount
                        Button {
                            HapticsManager.selection()
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                visibleDetailCount += 30
                            }
                        } label: {
                            Text("Xem thêm (\(remaining) dòng)")
                                .font(.caption.weight(.bold))
                                .monospacedDigit()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(theme.primaryLight)
                                .foregroundColor(theme.primary)
                                .clipShape(RoundedRectangle(cornerRadius: HrpDesignTokens.radiusXS, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    if snapshot.nextCursor != nil {
                        Button {
                            HapticsManager.lightImpact()
                            onLoadMoreFromServer()
                        } label: {
                            HStack(spacing: 8) {
                                if isLoadingMoreDrillDown {
                                    ProgressView()
                                        .scaleEffect(0.85)
                                }
                                Text(isLoadingMoreDrillDown ? "Đang tải thêm..." : "Tải thêm từ máy chủ")
                                    .font(.caption.weight(.bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(SemanticColors.surfaceMuted)
                            .foregroundColor(theme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: HrpDesignTokens.radiusXS, style: .continuous))
                        }
                        .disabled(isLoadingMoreDrillDown)
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(14)
            .hrpCardSurface(cornerRadius: HrpDesignTokens.radiusCard)
        }
    }

    private func teamKpiTile(
        label: String,
        value: String,
        subtitle: String,
        accentColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundColor(SemanticColors.textSecondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 21, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundColor(accentColor)
                .lineLimit(1)
            Text(subtitle)
                .font(.caption2.weight(.medium))
                .monospacedDigit()
                .foregroundColor(SemanticColors.textMuted)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .padding(12)
        .hrpMutedTile(cornerRadius: HrpDesignTokens.radiusMD)
    }
}

// MARK: - CCCD Review Section (`Chuẩn hoá thông tin NLĐ`)

public struct CccdReviewSectionView: View {
    @ObservedObject var viewModel: MiniBiViewModel

    private let statusFilters: [(String, String)] = [
        ("ALL", "Tất cả"),
        ("MISMATCH", "Lệch thông tin"),
        ("PENDING_QR", "Đang chờ QR"),
        ("UNREADABLE_QR", "QR mờ/lỗi"),
        ("MISSING_QR", "Thiếu ảnh"),
        ("MATCHED", "Đã khớp")
    ]

    public var body: some View {
        let theme = viewModel.selectedTheme

        VStack(alignment: .leading, spacing: 12) {
            // Status filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(statusFilters, id: \.0) { code, label in
                        let selected = viewModel.cccdReviewFilterStatus == code
                        Button {
                            HapticsManager.selection()
                            viewModel.cccdReviewFilterStatus = code
                            Task { await viewModel.loadCccdReviewItems() }
                        } label: {
                            Text(label)
                                .font(.caption.weight(selected ? .bold : .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .frame(minHeight: 32)
                                .background(selected ? theme.primary : Color.white)
                                .foregroundColor(selected ? .white : SemanticColors.textSecondary)
                                .clipShape(Capsule())
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(SemanticColors.textMuted)
                TextField("Tìm mã NLĐ, họ tên, số CCCD...", text: $viewModel.cccdReviewSearchQuery)
                    .submitLabel(.search)
                    .foregroundColor(SemanticColors.textPrimary)
                    .onSubmit {
                        KeyboardDismissal.dismiss()
                        Task { await viewModel.loadCccdReviewItems() }
                    }
                Button("Lọc") {
                    HapticsManager.lightImpact()
                    KeyboardDismissal.dismiss()
                    Task { await viewModel.loadCccdReviewItems() }
                }
                .font(.caption.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(minHeight: 34)
                .background(theme.primary)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: HrpDesignTokens.radiusXS, style: .continuous))
            }
            .padding(10)
            .hrpCardSurface(cornerRadius: HrpDesignTokens.radiusMD)

            if viewModel.cccdReviewItems.isEmpty {
                Text("Không có hồ sơ CCCD nào trong danh sách lọc.")
                    .font(.subheadline)
                    .foregroundColor(SemanticColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .hrpCardSurface(cornerRadius: HrpDesignTokens.radiusCard)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.cccdReviewItems) { item in
                        Button {
                            HapticsManager.selection()
                            viewModel.selectedCccdReviewItem = item
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(WorkerItem.isUuidLike(item.maNld) || item.maNld.isEmpty ? item.hoTen : "\(item.hoTen) (\(item.maNld))")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(SemanticColors.textPrimary)
                                    Spacer()
                                    Text(DirectEntryContract.reviewStatusDisplayLabel(item.reviewStatus))
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(statusBgColor(item.reviewStatus))
                                        .foregroundColor(statusTextColor(item.reviewStatus))
                                        .clipShape(Capsule())
                                }

                                Text("Dự án: \(item.duAn) · Quản lý: \(item.quanLy)")
                                    .font(.caption)
                                    .foregroundColor(SemanticColors.textSecondary)

                                HStack(spacing: 12) {
                                    Text("CCCD nhập: \(item.enteredCccd.isEmpty ? "—" : item.enteredCccd)")
                                        .font(.caption)
                                        .monospacedDigit()
                                        .foregroundColor(SemanticColors.textPrimary)
                                    Text("CCCD QR: \(item.qrCccd.isEmpty ? "—" : item.qrCccd)")
                                        .font(.caption.weight(.semibold))
                                        .monospacedDigit()
                                        .foregroundColor(theme.primary)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .hrpCardSurface(cornerRadius: HrpDesignTokens.radiusCard)
                        }
                        .buttonStyle(HrpPressableButtonStyle())
                    }

                    if viewModel.cccdReviewItems.count < viewModel.cccdReviewTotal {
                        HrpLoadMoreButton(
                            title: "Tải thêm hồ sơ duyệt CCCD",
                            loadedCount: viewModel.cccdReviewItems.count,
                            totalCount: viewModel.cccdReviewTotal,
                            isLoading: viewModel.isLoadingMoreCccdReview,
                            theme: theme
                        ) {
                            Task { await viewModel.loadMoreCccdReviewItems() }
                        }
                    }
                }
            }
        }
    }

    private func statusBgColor(_ status: String) -> Color {
        switch status.uppercased() {
        case DirectEntryContract.reviewStatusMatched:
            return SemanticColors.successBg
        case DirectEntryContract.reviewStatusMismatch:
            return SemanticColors.dangerBg
        default:
            return SemanticColors.warningBg
        }
    }

    private func statusTextColor(_ status: String) -> Color {
        switch status.uppercased() {
        case DirectEntryContract.reviewStatusMatched:
            return SemanticColors.successText
        case DirectEntryContract.reviewStatusMismatch:
            return SemanticColors.dangerText
        default:
            return SemanticColors.warningText
        }
    }
}

// MARK: - CCCD Review Detail Sheet

public struct CccdReviewDetailSheet: View {
    @ObservedObject var viewModel: MiniBiViewModel
    let item: CccdReviewItem
    @Environment(\.dismiss) private var dismiss
    @State private var correctedCccdInput: String = ""
    @State private var reviewNoteInput: String = ""

    public var body: some View {
        let theme = viewModel.selectedTheme

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(WorkerItem.isUuidLike(item.maNld) || item.maNld.isEmpty ? item.hoTen : "\(item.hoTen) (\(item.maNld))")
                            .font(.title3.weight(.bold))
                            .foregroundColor(SemanticColors.textPrimary)
                        Text("Dự án: \(item.duAn) · Quản lý: \(item.quanLy) · Tuyển: \(item.nguoiTuyen)")
                            .font(.caption)
                            .foregroundColor(SemanticColors.textSecondary)
                        Text("Trạng thái: \(DirectEntryContract.reviewStatusDisplayLabel(item.reviewStatus))")
                            .font(.caption.weight(.bold))
                            .foregroundColor(theme.primary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .cornerRadius(12)

                    // Front / Back CCCD Preview Links
                    if item.frontPreviewUrl != nil || item.backPreviewUrl != nil {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Ảnh CCCD Mặt trước / Mặt sau")
                                .font(.subheadline.weight(.bold))
                            HStack(spacing: 12) {
                                if let frontUrlStr = item.frontPreviewUrl, let url = URL(string: frontUrlStr) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable().scaledToFit()
                                        default:
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8).fill(Color(hex: 0xF1F5F9))
                                                Text("Mặt trước CCCD").font(.caption)
                                            }
                                        }
                                    }
                                    .frame(height: 130)
                                    .cornerRadius(8)
                                }
                                if let backUrlStr = item.backPreviewUrl, let url = URL(string: backUrlStr) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable().scaledToFit()
                                        default:
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8).fill(Color(hex: 0xF1F5F9))
                                                Text("Mặt sau CCCD").font(.caption)
                                            }
                                        }
                                    }
                                    .frame(height: 130)
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .cornerRadius(12)
                    }

                    // Comparison Table
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Đối chiếu dữ liệu nhập & dữ liệu QR CCCD")
                            .font(.subheadline.weight(.bold))

                        ForEach(item.comparisons) { row in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(row.label)
                                        .font(.caption.weight(.bold))
                                    Spacer()
                                    Text(row.status)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundColor(row.status == "MATCH" ? SemanticColors.successText : SemanticColors.warningText)
                                }
                                HStack {
                                    Text("Đã nhập: \(row.enteredValue.isEmpty ? "—" : row.enteredValue)")
                                        .font(.caption)
                                        .foregroundColor(SemanticColors.textSecondary)
                                    Spacer()
                                    Text("Từ QR: \(row.qrValue.isEmpty ? "—" : row.qrValue)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(theme.primary)
                                }
                            }
                            .padding(8)
                            .background(Color(hex: 0xF8FAFC))
                            .cornerRadius(8)
                        }
                    }
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(12)

                    // Actions: Standardize from QR or Update Entered CCCD
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Thao tác phê duyệt / chuẩn hoá")
                            .font(.subheadline.weight(.bold))

                        TextField("Số CCCD chuẩn (12 chữ số)...", text: $correctedCccdInput)
                            .submitLabel(.done)
                            .foregroundColor(SemanticColors.textPrimary)
                            .keyboardType(.numberPad)
                            .padding(10)
                            .background(Color(hex: 0xF8FAFC))
                            .cornerRadius(8)

                        TextField("Ghi chú duyệt / lý do...", text: $reviewNoteInput)
                            .submitLabel(.done)
                            .foregroundColor(SemanticColors.textPrimary)
                            .padding(10)
                            .background(Color(hex: 0xF8FAFC))
                            .cornerRadius(8)

                        HStack(spacing: 10) {
                            Button {
                                KeyboardDismissal.dismiss()
                                Task {
                                    let ok = await viewModel.resolveCccdReview(
                                        entryId: item.entryId,
                                        action: DirectEntryContract.resolveActionStandardizeFromQr,
                                        note: reviewNoteInput
                                    )
                                    if ok {
                                        dismiss()
                                    }
                                }
                            } label: {
                                Text("Chuẩn hoá theo QR")
                                    .font(.caption.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(theme.primary)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }

                            Button {
                                KeyboardDismissal.dismiss()
                                Task {
                                    let ok = await viewModel.resolveCccdReview(
                                        entryId: item.entryId,
                                        action: DirectEntryContract.resolveActionUpdateEnteredCccd,
                                        correctedCccd: correctedCccdInput.isEmpty ? item.enteredCccd : correctedCccdInput,
                                        note: reviewNoteInput
                                    )
                                    if ok {
                                        dismiss()
                                    }
                                }
                            } label: {
                                Text("Cập nhật CCCD nhập")
                                    .font(.caption.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(SemanticColors.successText)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }

                        Button {
                            KeyboardDismissal.dismiss()
                            Task {
                                await viewModel.retryCccdQrExtraction(entryId: item.entryId)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "qrcode.viewfinder")
                                Text("Quét / Trích xuất lại QR trên máy chủ")
                            }
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(theme.primaryLight)
                            .foregroundColor(theme.primary)
                            .cornerRadius(10)
                        }
                    }
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(12)
                }
                .padding(14)
            }
            .background(theme.background)
            .dismissKeyboardOnTapOutside()
            .navigationTitle("Chi tiết duyệt CCCD")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") {
                        KeyboardDismissal.dismiss()
                        dismiss()
                    }
                }
            }
            .onAppear {
                correctedCccdInput = item.enteredCccd
            }
        }
    }
}

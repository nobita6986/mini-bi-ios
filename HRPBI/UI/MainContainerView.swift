import SwiftUI

// MARK: - Main Container View (Top Bar + Notifications Sheet + Banner + Bottom Tab Bar)
// Mirrors Android's `MainActivity.kt` root scaffold 100%

public struct MainContainerView: View {
    @StateObject private var viewModel = MiniBiViewModel()

    public init() {}

    public var body: some View {
        let authTransitionKey = "\(viewModel.isAuthenticated)-\(viewModel.isBootstrapping)"

        Group {
            if viewModel.isAuthenticated {
                authenticatedScaffold
                    .transition(.opacity)
            } else if viewModel.isBootstrapping {
                BootstrapLaunchView(
                    theme: viewModel.selectedTheme,
                    env: viewModel.environmentConfig
                )
                .transition(.opacity)
            } else {
                LoginScreen(viewModel: viewModel)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: authTransitionKey)
        .preferredColorScheme(.light)
        .environment(\.colorScheme, .light)
        .dismissKeyboardOnTapOutside()
        .task {
            await viewModel.bootstrapSession()
        }
    }

    private var authenticatedScaffold: some View {
        let theme = viewModel.selectedTheme
        let env = viewModel.environmentConfig

        return VStack(spacing: 0) {
            // Top App Bar (iOS translucent material + subtle brand tint + 0.5pt bottom hairline)
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white)
                                .frame(width: 40, height: 40)
                                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(theme.topBarBorder.opacity(0.9), lineWidth: 0.8)
                                )
                            Image("hrpartner_logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 34, height: 34)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .accessibilityIdentifier("topbar_app_logo")

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("HRPartner")
                                    .font(.system(size: 17, weight: .heavy))
                                    .foregroundColor(SemanticColors.textPrimary)
                                Text(env.appBrandBadgeText)
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(theme.primary)
                                    )
                                    .foregroundColor(.white)
                            }
                            if let user = viewModel.currentUser {
                                Text(user.fullName)
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(SemanticColors.textSecondary)
                                    .lineLimit(1)
                                    .accessibilityIdentifier("topbar_user_fullname")
                            }
                        }
                    }

                    Spacer(minLength: 6)

                    HStack(spacing: 6) {
                        // HRPartner Bulletin ("Bản tin HRPartner") Button right next to Task Reminder Bell
                        Button {
                            HapticsManager.lightImpact()
                            viewModel.isBulletinSheetPresented = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "newspaper.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(theme.primary)
                                    .frame(width: 36, height: 36)
                                    .background(Color.white.opacity(0.92))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(theme.topBarBorder, lineWidth: 0.8)
                                    )
                                if viewModel.pinnedBulletinCount > 0 {
                                    Circle()
                                        .fill(theme.primary)
                                        .frame(width: 9, height: 9)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 1.5)
                                        )
                                        .offset(x: 1, y: 0)
                                }
                            }
                            .frame(minWidth: 40, minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(HrpPressableButtonStyle())
                        .accessibilityLabel("Bản tin HRPartner")
                        .accessibilityIdentifier("topbar_bulletin_button")

                        // Task Reminder Bell with Enabled Count Badge (>= 40x44pt hit target)
                        Button {
                            HapticsManager.lightImpact()
                            viewModel.refreshTaskReminders()
                            viewModel.isTaskReminderSheetPresented = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(theme.primary)
                                    .frame(width: 36, height: 36)
                                    .background(Color.white.opacity(0.92))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(theme.topBarBorder, lineWidth: 0.8)
                                    )
                                if viewModel.enabledRemindersCount > 0 {
                                    Text("\(min(99, viewModel.enabledRemindersCount))")
                                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                                        .contentTransition(.numericText())
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                        .offset(x: 4, y: -2)
                                }
                            }
                            .frame(minWidth: 40, minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(HrpPressableButtonStyle())
                        .accessibilityLabel("Nhắc việc")
                        .accessibilityIdentifier("topbar_reminder_button")

                        // Theme Selector & Logout Menu (>= 44x44pt hit target)
                        Menu {
                            Section("Giao diện màu sắc") {
                                ForEach(MiniBiThemes.all) { palette in
                                    Button {
                                        HapticsManager.selection()
                                        viewModel.selectTheme(palette)
                                    } label: {
                                        HStack {
                                            Text(palette.name)
                                            if palette.id == theme.id {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                            Divider()
                            Button(role: .destructive) {
                                HapticsManager.warning()
                                Task { await viewModel.performLogout() }
                            } label: {
                                Label("Đăng xuất", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "ellipsis.circle.fill")
                                    .font(.subheadline)
                                Text("Menu")
                                    .font(.caption.weight(.semibold))
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.92))
                            .foregroundColor(theme.primary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(theme.primary.opacity(0.26), lineWidth: 0.8)
                            )
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    ZStack {
                        Rectangle().fill(.ultraThinMaterial)
                        Rectangle().fill(theme.topBar.opacity(0.72))
                    }
                    .ignoresSafeArea(edges: .top)
                )

                Rectangle()
                    .fill(theme.topBarBorder.opacity(0.85))
                    .frame(height: 0.5)
            }

            // Active Screen Content + Floating Toast Layer (does not occupy layout space or shift UI)
            ZStack(alignment: .top) {
                Group {
                    switch viewModel.currentDestination {
                    case .dashboard:
                        DashboardScreen(viewModel: viewModel)
                    case .newEntry:
                        if viewModel.canAccessNewWorkerEntry {
                            DirectEntryNewWorkersScreen(viewModel: viewModel)
                        } else {
                            DashboardScreen(viewModel: viewModel)
                        }
                    case .workers:
                        WorkersScreen(viewModel: viewModel)
                    case .recruitment:
                        RecruitmentPostsScreen(viewModel: viewModel)
                    case .attendance:
                        AttendanceScreen(viewModel: viewModel)
                    case .workReports:
                        WorkReportsScreen(viewModel: viewModel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let message = viewModel.bannerMessage, !message.isEmpty {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: viewModel.bannerIsError ? "exclamationmark.octagon.fill" : "checkmark.circle.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(viewModel.bannerIsError ? SemanticColors.dangerText : SemanticColors.successText)

                        Text(message)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(viewModel.bannerIsError ? SemanticColors.dangerText : SemanticColors.successText)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 4)

                        Button {
                            HapticsManager.selection()
                            withAnimation(.easeOut(duration: 0.18)) {
                                viewModel.dismissBanner()
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(SemanticColors.textMuted)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.leading, 14)
                    .padding(.trailing, 4)
                    .padding(.vertical, 4)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: HrpDesignTokens.radiusCard, style: .continuous)
                                .fill(.ultraThinMaterial)
                            RoundedRectangle(cornerRadius: HrpDesignTokens.radiusCard, style: .continuous)
                                .fill((viewModel.bannerIsError ? SemanticColors.dangerBg : SemanticColors.successBg).opacity(0.88))
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: HrpDesignTokens.radiusCard, style: .continuous)
                            .stroke(
                                viewModel.bannerIsError ? SemanticColors.dangerBorder : SemanticColors.successBorder,
                                lineWidth: 0.8
                            )
                    )
                    .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 4)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onEnded { value in
                                if value.translation.height < -12 {
                                    withAnimation(.easeOut(duration: 0.18)) {
                                        viewModel.dismissBanner()
                                    }
                                }
                            }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(999)
                }
            }
            .animation(.easeOut(duration: 0.22), value: viewModel.bannerMessage)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Rectangle()
                .fill(SemanticColors.borderSubtle.opacity(0.85))
                .frame(height: 0.5)

            // Bottom Navigation Bar (Native HIG translucent bar, filled vs outline SF Symbols, >= 49pt height)
            let visibleDestinations = viewModel.visibleMainDestinations
            HStack(spacing: 0) {
                ForEach(visibleDestinations) { dest in
                    let isSelected = viewModel.currentDestination == dest
                    Button {
                        KeyboardDismissal.dismiss()
                        if viewModel.currentDestination != dest {
                            HapticsManager.selection()
                        }
                        viewModel.navigateTo(dest)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: dest.tabIconName(isSelected: isSelected))
                                .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                                .scaleEffect(isSelected ? 1.04 : 1.0)
                                .animation(.spring(response: 0.26, dampingFraction: 0.78), value: isSelected)
                            Text(dest.titleVi)
                                .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 49)
                        .padding(.vertical, 4)
                        .foregroundColor(isSelected ? theme.primary : SemanticColors.textMuted)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .background(
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    Rectangle().fill(Color.white.opacity(0.78))
                }
                .ignoresSafeArea(edges: .bottom)
            )
        }
        .sheet(isPresented: $viewModel.isBulletinSheetPresented) {
            HrpBulletinSheet(viewModel: viewModel)
                .hrpSheetPresentation(detents: [.medium, .large])
        }
        .sheet(isPresented: $viewModel.isTaskReminderSheetPresented) {
            TaskReminderSheet(viewModel: viewModel)
                .hrpSheetPresentation(detents: [.medium, .large])
        }
        .sheet(isPresented: $viewModel.isNotificationSheetPresented) {
            NotificationDrawerSheet(viewModel: viewModel)
                .hrpSheetPresentation(detents: [.medium, .large])
        }
    }
}

// MARK: - HRPartner Bulletin Sheet (Bản tin HRPartner)

public struct HrpBulletinSheet: View {
    @ObservedObject var viewModel: MiniBiViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: HrpBulletinItem? = nil

    public init(viewModel: MiniBiViewModel) {
        self.viewModel = viewModel
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
            .animation(.spring(response: 0.3, dampingFraction: 0.86), value: selectedItem?.id)
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Bản tin HRPartner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if selectedItem != nil {
                        Button {
                            HapticsManager.selection()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                                selectedItem = nil
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
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private func bulletinListView(theme: MiniBiThemePalette) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                // Category Filter Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(HrpBulletinCategory.allCases) { category in
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

                // Mockup Preview Notice Banner
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundColor(theme.primary)
                    Text("Bản tin nội bộ HRPartner (dữ liệu mẫu minh họa).")
                        .font(.caption)
                        .foregroundColor(SemanticColors.textSecondary)
                    Spacer(minLength: 0)
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
            withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                selectedItem = item
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(iconTint.opacity(0.12))
                            .frame(width: 38, height: 38)
                        Image(systemName: item.category.iconName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(iconTint)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(item.category.titleVi)
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
                            .font(.subheadline.weight(.bold))
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

                HStack {
                    Text(item.authorDisplay)
                        .font(.caption2)
                        .foregroundColor(SemanticColors.textMuted)
                    Spacer()
                    HStack(spacing: 3) {
                        Text("Xem chi tiết")
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
                borderColor: item.isPinned ? theme.primary.opacity(0.28) : SemanticColors.borderSubtle.opacity(0.85)
            )
        }
        .buttonStyle(HrpPressableButtonStyle())
    }

    private func bulletinDetailView(item: HrpBulletinItem, theme: MiniBiThemePalette) -> some View {
        let iconTint = categoryAccentColor(for: item.category, theme: theme)

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        HStack(spacing: 5) {
                            Image(systemName: item.category.iconName)
                                .font(.system(size: 11, weight: .semibold))
                            Text(item.category.titleVi)
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
            }
            .padding(14)
        }
    }

    private func categoryAccentColor(for category: HrpBulletinCategory, theme: MiniBiThemePalette) -> Color {
        switch category {
        case .all, .hrNews:
            return theme.primary
        case .holidaySchedule:
            return Color(hex: 0x0284C7)
        case .internalPolicy:
            return Color(hex: 0x15803D)
        }
    }
}

// MARK: - Cold-Start Bootstrap Launch Gate (Prevents Login Screen Flash While Resolving Session)

private struct BootstrapLaunchView: View {
    let theme: MiniBiThemePalette
    let env: AppEnvironmentConfig

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0xFFFBF8),
                    theme.background,
                    Color(hex: 0xF5F4F2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: HrpDesignTokens.radiusHero, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 72, height: 72)
                        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: HrpDesignTokens.radiusHero, style: .continuous)
                                .stroke(SemanticColors.borderSubtle.opacity(0.85), lineWidth: 0.8)
                        )
                    Image("hrpartner_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 58, height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Text(env.appBrandTitle)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(SemanticColors.textPrimary)

                ProgressView()
                    .tint(theme.primary)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - Notification Drawer Sheet

struct NotificationDrawerSheet: View {
    @ObservedObject var viewModel: MiniBiViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let theme = viewModel.selectedTheme

        NavigationStack {
            List {
                if viewModel.notifications.isEmpty {
                    Text("Chưa có thông báo mới.")
                        .font(.subheadline)
                        .foregroundColor(SemanticColors.textSecondary)
                } else {
                    ForEach(viewModel.notifications) { item in
                        Button {
                            Task {
                                await viewModel.handleNotificationTap(item)
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(item.isRead ? Color.clear : theme.primary)
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 6)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.subheadline.weight(item.isRead ? .medium : .bold))
                                        .foregroundColor(SemanticColors.textPrimary)
                                    if !item.body.isEmpty {
                                        Text(item.body)
                                            .font(.caption)
                                            .foregroundColor(SemanticColors.textSecondary)
                                    }
                                    Text(WorkReportsContract.formatIsoDateTimeVi(item.createdAt))
                                        .font(.caption2)
                                        .foregroundColor(SemanticColors.textMuted)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Thông báo (\(viewModel.unreadNotificationCount))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.unreadNotificationCount > 0 {
                        Button("Đọc tất cả") {
                            Task { await viewModel.markAllNotificationsRead() }
                        }
                    }
                }
            }
        }
    }
}

import Foundation

// MARK: - Work Reports Contract & Reporting Service
// Mirrors Android's `data/WorkReportsAndReportingService.kt` 100%

public enum WorkReportsContract {
    public static let obligationStatusActive = "ACTIVE"
    public static let obligationStatusCancelled = "CANCELLED"
    public static let obligationStatusExempted = "EXEMPTED"

    public static let stateNotStarted = "NOT_STARTED"
    public static let stateDraft = "DRAFT"
    public static let stateSubmitted = "SUBMITTED"
    public static let stateApproved = "APPROVED"
    public static let stateRejected = "REJECTED"

    public static let decisionApprove = "APPROVE"
    public static let decisionReject = "REJECT"

    public static let codeDeadlinePassed = "WORK_REPORT_DEADLINE_PASSED"
    public static let codeVersionConflict = "WORK_REPORT_VERSION_CONFLICT"
    public static let deadlinePassedMessageVi = "Đã quá hạn nộp báo cáo."
    public static let obligationInactiveMessageVi = "Kỳ báo cáo này thuộc đợt giao đã thu hồi hoặc được miễn nộp."

    public static func submissionStateDisplayLabel(_ state: String) -> String {
        switch state.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case stateNotStarted:
            return "Chưa bắt đầu"
        case stateDraft:
            return "Bản nháp"
        case stateSubmitted, "PENDING_REVIEW":
            return "Đã nộp · Chờ duyệt"
        case stateApproved, "COMPLETED":
            return "Đã phê duyệt"
        case stateRejected:
            return "Cần bổ sung / Từ chối"
        default:
            return state.isEmpty ? "—" : state
        }
    }

    public static func obligationBadgeDisplayLabel(_ obligation: WorkReportObligationItem) -> String {
        let normalizedStatus = obligation.obligationStatus.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let normalizedState = obligation.submissionState.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if normalizedStatus == obligationStatusCancelled && normalizedState == stateNotStarted {
            return "Đã hủy đợt giao"
        }
        if normalizedStatus == obligationStatusExempted && normalizedState == stateNotStarted {
            return "Được miễn nộp"
        }
        if obligation.isOverdue {
            switch normalizedState {
            case stateNotStarted:
                return "Quá hạn · Chưa nộp"
            case stateDraft:
                return "Quá hạn · Bản nháp chưa nộp"
            default:
                break
            }
        }
        return submissionStateDisplayLabel(obligation.submissionState)
    }

    public static func isActionableState(_ state: String) -> Bool {
        let normalized = state.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return normalized == stateNotStarted || normalized == stateDraft || normalized == stateRejected
    }

    /// Relies strictly on server `obligationStatus == "ACTIVE"`, `isOverdue`, and `submissionState`.
    /// Never locks `REJECTED` locally based on device clock vs `dueAt`.
    public static func isActionableObligation(_ obligation: WorkReportObligationItem) -> Bool {
        let normalizedStatus = obligation.obligationStatus.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return normalizedStatus == obligationStatusActive
            && !obligation.isOverdue
            && isActionableState(obligation.submissionState)
    }

    /// Mirrors Android `WorkReportsAndReportingService.isHistoryObligation`:
    /// Excludes `CANCELLED` obligations that were never started (`NOT_STARTED`) so revoked assignments do not clutter History.
    public static func isHistoryObligation(_ obligation: WorkReportObligationItem) -> Bool {
        if isActionableObligation(obligation) {
            return false
        }
        let normalizedStatus = obligation.obligationStatus.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let normalizedState = obligation.submissionState.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return obligation.isOverdue
            || normalizedState != stateNotStarted
            || normalizedStatus == obligationStatusExempted
    }

    public static func isEditableObligation(_ obligation: WorkReportObligationItem) -> Bool {
        isActionableObligation(obligation)
    }

    public static func periodTypeDisplayLabel(_ periodType: String) -> String {
        switch periodType.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "DAILY":
            return "Hàng ngày"
        case "WEEKLY":
            return "Hàng tuần"
        case "MONTHLY":
            return "Hàng tháng"
        default:
            return periodType
        }
    }

    public static func formatPeriodKeyVi(_ periodKey: String) -> String {
        let trimmed = periodKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "—" }
        // Match YYYY-MM-DD -> DD/MM/YYYY
        let parts = trimmed.split(separator: "-")
        if parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2 {
            return "\(parts[2])/\(parts[1])/\(parts[0])"
        }
        if parts.count == 2, parts[0].count == 4, parts[1].count == 2 {
            return "Tháng \(parts[1])/\(parts[0])"
        }
        return trimmed
    }

    public static func formatIsoDateTimeVi(_ rawIso: String?) -> String {
        guard let rawIso, !rawIso.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "—"
        }
        let trimmed = rawIso.trimmingCharacters(in: .whitespacesAndNewlines)
        if let epochMs = AttendanceTimeAnchorManager.parseIso8601ToEpochMs(trimmed) {
            let date = Date(timeIntervalSince1970: Double(epochMs) / 1000.0)
            let df = DateFormatter()
            df.locale = Locale(identifier: "vi_VN")
            df.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .current
            df.dateFormat = "HH:mm dd/MM/yyyy"
            return df.string(from: date)
        }
        return formatPeriodKeyVi(trimmed)
    }

    public static func formatPercentVi(_ ratioOrPercent: Double) -> String {
        let pct = ratioOrPercent <= 1.0 && ratioOrPercent > 0.0 ? ratioOrPercent * 100.0 : ratioOrPercent
        return String(format: "%.1f%%", pct)
    }

    public static func normalizeDateIso(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let prefix10 = String(trimmed.prefix(10))
        let parts = prefix10.split(separator: "/")
        if parts.count == 3, parts[0].count == 2, parts[1].count == 2, parts[2].count == 4 {
            return "\(parts[2])-\(parts[1])-\(parts[0])"
        }
        return prefix10
    }

    public static func computeHiringDaySummary(byDateCounts: [String: Int]) -> HiringDaySummary {
        let positive = byDateCounts
            .map { (date: normalizeDateIso($0.key), count: $0.value) }
            .filter { !$0.date.isEmpty && $0.count > 0 }
        guard !positive.isEmpty else {
            return HiringDaySummary()
        }
        var merged: [String: Int] = [:]
        for item in positive {
            merged[item.date, default: 0] += item.count
        }
        let activeDays = merged.count
        let totalCount = merged.values.reduce(0, +)
        let avg = Double(totalCount) / Double(activeDays)
        let peak = merged.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key > rhs.key
        }.first
        return HiringDaySummary(
            activeHiringDays: activeDays,
            avgPerActiveDay: avg,
            peakDailyCount: peak?.value,
            peakDateIso: peak?.key
        )
    }

    public static func extractByDateCounts(
        from report: [String: Any],
        fallbackRows: [TeamDrillDownItem] = []
    ) -> [String: Int] {
        var counts: [String: Int] = [:]
        for key in ["byDate", "by_date"] {
            if let dict = report[key] as? [String: Any] {
                for (k, v) in dict {
                    let dateIso = normalizeDateIso(k)
                    guard !dateIso.isEmpty else { continue }
                    let cnt: Int
                    if let i = v as? Int {
                        cnt = i
                    } else if let n = v as? NSNumber {
                        cnt = n.intValue
                    } else if let obj = v as? [String: Any] {
                        cnt = obj.optInt("recruitedCount", "recruited_count", "count", "total", "total_count", "eligible_episode_count")
                    } else if let s = v as? String, let parsed = Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        cnt = parsed
                    } else {
                        cnt = 0
                    }
                    if cnt > 0 {
                        counts[dateIso, default: 0] += cnt
                    }
                }
            } else {
                let arr = report.optObjectArray(key)
                for obj in arr {
                    let dateIso = normalizeDateIso(obj.optString("date", "businessDate", "business_date", "key"))
                    let cnt = obj.optInt("recruitedCount", "recruited_count", "count", "total", "total_count", "eligible_episode_count")
                    if !dateIso.isEmpty && cnt > 0 {
                        counts[dateIso, default: 0] += cnt
                    }
                }
            }
            if !counts.isEmpty { break }
        }
        if counts.isEmpty && !fallbackRows.isEmpty {
            for row in fallbackRows {
                let dateIso = normalizeDateIso(row.businessDate)
                if !dateIso.isEmpty && row.recruitedCount > 0 {
                    counts[dateIso, default: 0] += row.recruitedCount
                }
            }
        }
        return counts
    }

    public static func computeHiringDaySummary(
        fromReport report: [String: Any],
        fallbackRows: [TeamDrillDownItem] = []
    ) -> HiringDaySummary {
        let counts = extractByDateCounts(from: report, fallbackRows: fallbackRows)
        return computeHiringDaySummary(byDateCounts: counts)
    }

    public static func computeHiringDaySummary(fromDrillDownRows rows: [TeamDrillDownItem]) -> HiringDaySummary {
        var counts: [String: Int] = [:]
        for row in rows {
            let dateIso = normalizeDateIso(row.businessDate)
            if !dateIso.isEmpty && row.recruitedCount > 0 {
                counts[dateIso, default: 0] += row.recruitedCount
            }
        }
        return computeHiringDaySummary(byDateCounts: counts)
    }

    public static func computeHiringDaySummary(fromWorkers workers: [WorkerItem]) -> HiringDaySummary {
        var counts: [String: Int] = [:]
        for w in workers {
            let dateIso = normalizeDateIso(w.ngayVaoLam)
            if !dateIso.isEmpty {
                counts[dateIso, default: 0] += 1
            }
        }
        return computeHiringDaySummary(byDateCounts: counts)
    }

    public static func parseDynamicSections(_ schemaRaw: Any?) -> [WorkReportSectionSchema] {
        let dict: [String: Any]?
        if let d = schemaRaw as? [String: Any] {
            dict = d
        } else if let str = schemaRaw as? String,
                  let data = str.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            dict = parsed
        } else {
            dict = nil
        }

        func parseFieldObject(_ fObj: [String: Any], fallbackIndex: Int) -> (sectionKey: String, sortOrder: Int, field: WorkReportFieldSchema)? {
            let fieldId = fObj.optString("field_key", "id", "key", "name", "field_id")
            guard !fieldId.isEmpty else { return nil }
            let sectionKey = fObj.optString("section_key", "section_id", "group_key", defaultValue: "default")
            let sortOrder = fObj.optInt("sort_order", "order", defaultValue: (fallbackIndex + 1) * 10)
            let label = fObj.optString("label", "title", "name", defaultValue: fieldId)
            let type = fObj.optString("field_type", "type", defaultValue: "text").lowercased()
            let required = fObj.optBool("required", "is_required", defaultValue: false)
            let placeholder = fObj.optNullableString("description", "placeholder", "hint", "help_text")
            let defaultValue: String? = {
                if let rawDefault = fObj["default_value"], !(rawDefault is NSNull) {
                    if let b = rawDefault as? Bool {
                        return b ? "true" : "false"
                    } else if let n = rawDefault as? NSNumber {
                        if CFGetTypeID(n) == CFBooleanGetTypeID() {
                            return n.boolValue ? "true" : "false"
                        }
                        return n.stringValue
                    } else if let s = rawDefault as? String {
                        return s
                    }
                }
                return nil
            }()
            var options: [WorkReportFieldOption] = []
            if let optObjs = fObj["options"] as? [[String: Any]] {
                options = optObjs.compactMap { o in
                    let val = o.optString("option_key", "value", "id", "code", "key", "label")
                    guard !val.isEmpty else { return nil }
                    let lbl = o.optString("label", "name", "title", "value", defaultValue: val)
                    return WorkReportFieldOption(value: val, label: lbl)
                }
            } else if let optStrs = fObj["options"] as? [String] {
                options = optStrs.map { WorkReportFieldOption(value: $0, label: $0) }
            }
            let schema = WorkReportFieldSchema(
                id: fieldId,
                label: label,
                type: type,
                required: required,
                placeholder: placeholder,
                defaultValue: defaultValue,
                options: options,
                min: fObj.optNullableDouble("min", "min_value"),
                max: fObj.optNullableDouble("max", "max_value")
            )
            return (sectionKey, sortOrder, schema)
        }

        if let dict {
            let rawSections = dict.optObjectArray("sections").ifEmpty(dict.optObjectArray("groups"))
            let topLevelFieldsRaw = dict.optObjectArray("fields").ifEmpty(dict.optObjectArray("items"))

            var parsedTopFields: [(sectionKey: String, sortOrder: Int, field: WorkReportFieldSchema)] = []
            for (idx, fObj) in topLevelFieldsRaw.enumerated() {
                if let item = parseFieldObject(fObj, fallbackIndex: idx) {
                    parsedTopFields.append(item)
                }
            }

            var result: [WorkReportSectionSchema] = []
            var consumedFieldIds: Set<String> = []

            let sortedSections = rawSections.enumerated().sorted { lhs, rhs in
                let lOrder = lhs.element.optInt("sort_order", "order", defaultValue: (lhs.offset + 1) * 10)
                let rOrder = rhs.element.optInt("sort_order", "order", defaultValue: (rhs.offset + 1) * 10)
                return lOrder == rOrder ? lhs.offset < rhs.offset : lOrder < rOrder
            }

            for (secIdx, secObj) in sortedSections {
                let secId = secObj.optString("section_key", "id", "section_id", "key", defaultValue: "sec_\(secIdx)")
                let secTitle = secObj.optString("label", "title", "name", defaultValue: "Phần \(secIdx + 1)")
                let secDesc = secObj.optNullableString("description", "subtitle")

                var secFieldsWithOrder: [(sortOrder: Int, field: WorkReportFieldSchema)] = []
                let nestedRaw = secObj.optObjectArray("fields").ifEmpty(secObj.optObjectArray("items"))
                for (fIdx, fObj) in nestedRaw.enumerated() {
                    if let parsed = parseFieldObject(fObj, fallbackIndex: fIdx) {
                        secFieldsWithOrder.append((parsed.sortOrder, parsed.field))
                        consumedFieldIds.insert(parsed.field.id)
                    }
                }

                for topField in parsedTopFields where topField.sectionKey == secId && !consumedFieldIds.contains(topField.field.id) {
                    secFieldsWithOrder.append((topField.sortOrder, topField.field))
                    consumedFieldIds.insert(topField.field.id)
                }

                let orderedFields = secFieldsWithOrder.sorted { $0.sortOrder < $1.sortOrder }.map(\.field)
                if !orderedFields.isEmpty {
                    result.append(
                        WorkReportSectionSchema(
                            id: secId,
                            title: secTitle,
                            description: secDesc,
                            fields: orderedFields
                        )
                    )
                }
            }

            let remainingFields = parsedTopFields
                .filter { !consumedFieldIds.contains($0.field.id) }
                .sorted { $0.sortOrder < $1.sortOrder }
                .map(\.field)

            if !remainingFields.isEmpty {
                if result.count == 1 && rawSections.count == 1 {
                    let only = result[0]
                    result[0] = WorkReportSectionSchema(
                        id: only.id,
                        title: only.title,
                        description: only.description,
                        fields: only.fields + remainingFields
                    )
                } else {
                    result.append(
                        WorkReportSectionSchema(
                            id: "default",
                            title: "Nội dung báo cáo",
                            description: nil,
                            fields: remainingFields
                        )
                    )
                }
            }

            return result
        }

        if let arr = schemaRaw as? [[String: Any]] {
            let fields = arr.enumerated().compactMap { idx, fObj in
                parseFieldObject(fObj, fallbackIndex: idx)?.field
            }
            if !fields.isEmpty {
                return [
                    WorkReportSectionSchema(
                        id: "default",
                        title: "Nội dung báo cáo",
                        description: nil,
                        fields: fields
                    )
                ]
            }
        }

        return []
    }

    public static func normalizeIsoDateInput(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let dashParts = trimmed.split(separator: "-")
        if dashParts.count == 3, dashParts[0].count == 4, dashParts[1].count == 2, dashParts[2].count == 2,
           let m = Int(dashParts[1]), (1...12).contains(m),
           let d = Int(dashParts[2]), (1...31).contains(d) {
            return trimmed
        }
        let slashParts = trimmed.split(separator: "/")
        if slashParts.count == 3, slashParts[2].count == 4,
           let d = Int(slashParts[0]), (1...31).contains(d),
           let m = Int(slashParts[1]), (1...12).contains(m) {
            let dd = String(format: "%02d", d)
            let mm = String(format: "%02d", m)
            return "\(slashParts[2])-\(mm)-\(dd)"
        }
        return nil
    }

    /// Validates dynamic work-report form fields before final submit (`Nộp báo cáo`).
    /// Note: Boolean toggle fields (`Có / Đạt` vs `Không`) are always valid whether `true` or `false` (`Không`),
    /// matching Android's `DynamicWorkReportFormCard.buildPayloadJson(strictForSubmit = true)`.
    public static func validateFormPayloadForSubmit(
        formPayload: [String: String],
        sections: [WorkReportSectionSchema]
    ) -> String? {
        let allFields = sections.flatMap(\.fields)
        for field in allFields {
            let raw = (formPayload[field.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let typeLower = field.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let isBoolean = field.isBooleanType
            if field.required && raw.isEmpty && !isBoolean {
                return "Vui lòng nhập trường bắt buộc: \(field.label)"
            }
            if raw.isEmpty { continue }
            switch typeLower {
            case "integer":
                if Int64(raw) == nil {
                    return "Trường \"\(field.label)\" phải là số nguyên hợp lệ."
                }
            case "decimal", "number", "numeric", "float":
                let normalized = raw.replacingOccurrences(of: ",", with: ".")
                if let d = Double(normalized), d.isFinite {
                    // valid
                } else {
                    return "Trường \"\(field.label)\" phải là số hợp lệ."
                }
            case "date":
                if normalizeIsoDateInput(raw) == nil {
                    return "Trường \"\(field.label)\" phải có định dạng ngày YYYY-MM-DD hoặc DD/MM/YYYY."
                }
            case "single_select", "select", "dropdown", "radio":
                if !field.options.isEmpty && !field.options.contains(where: { $0.value == raw }) {
                    return "Giá trị đã chọn cho \"\(field.label)\" không hợp lệ."
                }
            case "multi_select", "multiselect":
                let items = raw
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                if field.required && items.isEmpty {
                    return "Vui lòng chọn ít nhất 1 mục cho: \(field.label)"
                }
            default:
                break
            }
        }
        return nil
    }

    public static func buildTypedPayloadJson(
        formPayload: [String: String],
        sections: [WorkReportSectionSchema]
    ) -> [String: Any] {
        var payloadJson: [String: Any] = [:]
        var processedKeys: Set<String> = []

        for sec in sections {
            for field in sec.fields {
                let key = field.id
                processedKeys.insert(key)
                let rawVal = formPayload[key] ?? field.defaultValue ?? ""
                let trimmed = rawVal.trimmingCharacters(in: .whitespacesAndNewlines)
                let fieldType = field.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

                switch fieldType {
                case "boolean", "bool", "checkbox", "switch":
                    let lower = trimmed.lowercased()
                    payloadJson[key] = ["true", "1", "yes", "có"].contains(lower)

                case "integer":
                    if trimmed.isEmpty { continue }
                    if let intVal = Int64(trimmed) {
                        payloadJson[key] = intVal
                    }

                case "number", "numeric", "decimal", "float":
                    if trimmed.isEmpty { continue }
                    let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
                    if let intVal = Int64(normalized), !normalized.contains(".") {
                        payloadJson[key] = intVal
                    } else if let dblVal = Double(normalized), dblVal.isFinite {
                        payloadJson[key] = dblVal
                    }

                case "date":
                    if trimmed.isEmpty { continue }
                    payloadJson[key] = normalizeIsoDateInput(trimmed) ?? trimmed

                case "multi_select", "multiselect":
                    if trimmed.isEmpty {
                        if field.required {
                            payloadJson[key] = [String]()
                        }
                    } else if trimmed.hasPrefix("["),
                              let data = trimmed.data(using: .utf8),
                              let arr = try? JSONSerialization.jsonObject(with: data) as? [String] {
                        payloadJson[key] = arr.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                    } else {
                        let parts = trimmed
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        payloadJson[key] = parts
                    }

                default:
                    if !trimmed.isEmpty {
                        payloadJson[key] = trimmed
                    }
                }
            }
        }

        // Preserve any extra/untyped keys when sections is empty or contains custom keys
        for (key, rawVal) in formPayload where !processedKeys.contains(key) {
            let trimmed = rawVal.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                payloadJson[key] = trimmed
            }
        }
        return payloadJson
    }

    public static func buildSubmissionMutationBody(
        payloadJson: [String: Any],
        expectedVersion: Int?,
        idempotencyKey: String
    ) -> [String: Any] {
        return [
            "payload_json": payloadJson,
            "expected_version": expectedVersion ?? NSNull(),
            "idempotency_key": idempotencyKey
        ]
    }
}

public struct PeriodAllScopeAggregation {
    public let totalWorkers: Int
    public let activeCount: Int
    public let inactiveCount: Int
    public let unconfirmedCount: Int
    public let projects: [ProjectBreakdownRow]
    public let recruiters: [PersonPerformanceRow]
    public let managers: [PersonPerformanceRow]
    public let teamBuckets: [DistributionBucket]
    public let providerBuckets: [DistributionBucket]
    public let teams: [TeamSummaryRow]
    public let byRecruiterItems: [BiBucketItem]
    public let byProjectItems: [BiBucketItem]
    public let byTeamItems: [BiBucketItem]
    public let byProviderItems: [BiBucketItem]
    public let hiringSummary: HiringDaySummary
}

private actor DashboardReportingCoalescer {
    private var inFlightWorkforceDeep: [String: Task<BackendHttpResponse, Never>] = [:]
    private var cachedWorkforceDeep: [String: (timestamp: Date, response: BackendHttpResponse)] = [:]

    private var inFlightPeriodAgg: [String: Task<PeriodAllScopeAggregation?, Never>] = [:]
    private var cachedPeriodAgg: [String: (timestamp: Date, value: PeriodAllScopeAggregation)] = [:]

    private var cachedAdminTeamMap: [String: String]?
    private var verifiedCatalogTeamCodes: Set<String> = []
    private var inFlightAdminTeamMap: Task<([String: String], Set<String>), Never>?

    private let cacheTtlSeconds: TimeInterval = 2.5

    func fetchAdminTeamMap(
        canFetchRemote: Bool,
        defaultMap: [String: String],
        loader: @escaping @Sendable () async -> ([String: String], Set<String>)
    ) async -> (map: [String: String], verifiedCodes: Set<String>) {
        if let cachedAdminTeamMap {
            return (cachedAdminTeamMap, verifiedCatalogTeamCodes)
        }
        guard canFetchRemote else {
            return (defaultMap, verifiedCatalogTeamCodes)
        }
        if let existing = inFlightAdminTeamMap {
            let res = await existing.value
            return (res.0, res.1)
        }
        let task = Task {
            await loader()
        }
        inFlightAdminTeamMap = task
        let (loadedMap, verified) = await task.value
        inFlightAdminTeamMap = nil
        if !loadedMap.isEmpty {
            cachedAdminTeamMap = loadedMap
            verifiedCatalogTeamCodes.formUnion(verified)
            return (loadedMap, verifiedCatalogTeamCodes)
        }
        return (defaultMap, verifiedCatalogTeamCodes)
    }

    func fetchWorkforceDeep(
        key: String,
        loader: @escaping @Sendable () async -> BackendHttpResponse
    ) async -> BackendHttpResponse {
        let now = Date()
        if let hit = cachedWorkforceDeep[key], now.timeIntervalSince(hit.timestamp) <= cacheTtlSeconds {
            return hit.response
        }
        if let existing = inFlightWorkforceDeep[key] {
            return await existing.value
        }
        let task = Task {
            await loader()
        }
        inFlightWorkforceDeep[key] = task
        let response = await task.value
        inFlightWorkforceDeep.removeValue(forKey: key)
        if response.isSuccess {
            cachedWorkforceDeep[key] = (Date(), response)
        }
        return response
    }

    func fetchPeriodAggregation(
        key: String,
        loader: @escaping @Sendable () async -> PeriodAllScopeAggregation?
    ) async -> PeriodAllScopeAggregation? {
        let now = Date()
        if let hit = cachedPeriodAgg[key], now.timeIntervalSince(hit.timestamp) <= cacheTtlSeconds {
            return hit.value
        }
        if let existing = inFlightPeriodAgg[key] {
            return await existing.value
        }
        let task = Task {
            await loader()
        }
        inFlightPeriodAgg[key] = task
        let result = await task.value
        inFlightPeriodAgg.removeValue(forKey: key)
        if let result {
            cachedPeriodAgg[key] = (Date(), result)
        }
        return result
    }
}

public final class WorkReportsAndReportingService {
    public static let shared = WorkReportsAndReportingService()

    private let httpClient: BackendHttpClient
    private let reportingCoalescer = DashboardReportingCoalescer()
    public private(set) var lastPendingReviewsNextCursor: String? = nil
    public private(set) var lastPendingReviewsHasMore: Bool = false

    public init(httpClient: BackendHttpClient = .shared) {
        self.httpClient = httpClient
    }

    // MARK: - 1. Work Report Obligations (`GET /api/work-reports/obligations`)

    public func fetchMyObligations(
        submissionState: String? = nil,
        periodKey: String? = nil,
        pageSize: Int? = nil
    ) async -> MiniBiApiResult<[WorkReportObligationItem]> {
        var queryItems: [URLQueryItem] = []
        if let submissionState, !submissionState.isEmpty {
            queryItems.append(URLQueryItem(name: "submission_state", value: submissionState))
        }
        if let periodKey, !periodKey.isEmpty {
            queryItems.append(URLQueryItem(name: "period_key", value: periodKey))
        }
        if let pageSize, pageSize > 0 {
            queryItems.append(URLQueryItem(name: "page_size", value: String(min(pageSize, 100))))
        }

        let response = await httpClient.request(
            method: "GET",
            path: "/api/work-reports/obligations",
            queryItems: queryItems
        )
        guard response.isSuccess else {
            return .failure(
                message: response.errorMessage ?? "Không tải được danh sách báo cáo công việc.",
                httpStatus: response.statusCode,
                errorCode: response.errorCode
            )
        }

        let root = response.jsonObject ?? [:]
        let itemsArr = root.optObjectArray("data")
            .ifEmpty(root.optObjectArray("obligations"))
            .ifEmpty(root.optObjectArray("items"))
            .ifEmpty((root["data"] as? [String: Any])?.optObjectArray("obligations") ?? [])
            .ifEmpty((root["data"] as? [String: Any])?.optObjectArray("items") ?? [])

        let parsed = itemsArr.map { Self.parseObligationItem($0) }
        return .success(parsed, statusCode: response.statusCode)
    }

    public func fetchObligationDetail(obligationId: Int64) async -> MiniBiApiResult<WorkReportObligationItem> {
        await fetchObligationDetail(obligationIdUuid: String(obligationId))
    }

    public func fetchObligationDetail(
        obligationIdUuid: String,
        fallback: WorkReportObligationItem? = nil
    ) async -> MiniBiApiResult<WorkReportObligationItem> {
        let encoded = obligationIdUuid.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? obligationIdUuid
        let response = await httpClient.request(
            method: "GET",
            path: "/api/work-reports/obligations/\(encoded)"
        )
        guard response.isSuccess else {
            return .failure(
                message: response.errorMessage ?? "Không tải được chi tiết báo cáo công việc.",
                httpStatus: response.statusCode,
                errorCode: response.errorCode
            )
        }

        let root = response.jsonObject ?? [:]
        let dataObj = (root["data"] as? [String: Any]) ?? root
        let obObj = (dataObj["obligation"] as? [String: Any])
            ?? (root["obligation"] as? [String: Any])
            ?? (root["item"] as? [String: Any])
            ?? dataObj

        let parsed = Self.parseObligationItem(obObj, fallbackRoot: dataObj, fallback: fallback)
        return .success(parsed, statusCode: response.statusCode)
    }

    // MARK: - 2. Save Draft & Submit Report (with `WORK_REPORT_DEADLINE_PASSED` handling)

    public func saveDraft(
        submissionId: Int64,
        version: Int,
        formPayload: [String: String]
    ) async -> MiniBiApiResult<WorkReportObligationItem> {
        await saveDraft(
            obligationIdUuid: String(submissionId),
            expectedVersion: version > 0 ? version : nil,
            formPayload: formPayload,
            sections: []
        )
    }

    public func saveDraft(
        obligationIdUuid: String,
        expectedVersion: Int?,
        formPayload: [String: String],
        sections: [WorkReportSectionSchema] = [],
        fallback: WorkReportObligationItem? = nil
    ) async -> MiniBiApiResult<WorkReportObligationItem> {
        let typedPayload = WorkReportsContract.buildTypedPayloadJson(formPayload: formPayload, sections: sections)
        let idempotencyKey = UUID().uuidString.lowercased()
        let body = WorkReportsContract.buildSubmissionMutationBody(
            payloadJson: typedPayload,
            expectedVersion: expectedVersion,
            idempotencyKey: idempotencyKey
        )

        let encoded = obligationIdUuid.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? obligationIdUuid
        let response = await httpClient.request(
            method: "POST",
            path: "/api/work-reports/submissions/\(encoded)/draft",
            jsonBody: body,
            additionalHeaders: ["Idempotency-Key": idempotencyKey]
        )

        if response.statusCode == 409 {
            return Self.handleWorkReportConflictResponse(response)
        }

        guard response.isSuccess else {
            return .failure(
                message: response.errorMessage ?? "Lưu nháp báo cáo thất bại.",
                httpStatus: response.statusCode,
                errorCode: response.errorCode
            )
        }

        if case .success(let refreshed, _) = await fetchObligationDetail(obligationIdUuid: obligationIdUuid, fallback: fallback) {
            return .success(refreshed, statusCode: response.statusCode)
        }

        let root = response.jsonObject ?? [:]
        let dataObj = (root["data"] as? [String: Any]) ?? root
        let obj = (dataObj["obligation"] as? [String: Any])
            ?? (dataObj["submission"] as? [String: Any])
            ?? (root["submission"] as? [String: Any])
            ?? (root["obligation"] as? [String: Any])
            ?? dataObj
        var item = Self.parseObligationItem(obj, fallbackRoot: dataObj, fallback: fallback)
        if item.sections.isEmpty && !sections.isEmpty {
            item.sections = sections
        }
        if item.formPayload.isEmpty {
            item.formPayload = formPayload
        }
        return .success(item, statusCode: response.statusCode)
    }

    public func submitReport(
        submissionId: Int64,
        version: Int,
        formPayload: [String: String]
    ) async -> MiniBiApiResult<WorkReportObligationItem> {
        await submitReport(
            obligationIdUuid: String(submissionId),
            expectedVersion: version > 0 ? version : nil,
            formPayload: formPayload,
            sections: []
        )
    }

    public func submitReport(
        obligationIdUuid: String,
        expectedVersion: Int?,
        formPayload: [String: String],
        sections: [WorkReportSectionSchema] = [],
        fallback: WorkReportObligationItem? = nil
    ) async -> MiniBiApiResult<WorkReportObligationItem> {
        let typedPayload = WorkReportsContract.buildTypedPayloadJson(formPayload: formPayload, sections: sections)
        let idempotencyKey = UUID().uuidString.lowercased()
        let body = WorkReportsContract.buildSubmissionMutationBody(
            payloadJson: typedPayload,
            expectedVersion: expectedVersion,
            idempotencyKey: idempotencyKey
        )

        let encoded = obligationIdUuid.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? obligationIdUuid
        let response = await httpClient.request(
            method: "POST",
            path: "/api/work-reports/submissions/\(encoded)/submit",
            jsonBody: body,
            additionalHeaders: ["Idempotency-Key": idempotencyKey]
        )

        if response.statusCode == 409 {
            return Self.handleWorkReportConflictResponse(response)
        }

        guard response.isSuccess else {
            return .failure(
                message: response.errorMessage ?? "Nộp báo cáo thất bại.",
                httpStatus: response.statusCode,
                errorCode: response.errorCode
            )
        }

        if case .success(let refreshed, _) = await fetchObligationDetail(obligationIdUuid: obligationIdUuid, fallback: fallback) {
            return .success(refreshed, statusCode: response.statusCode)
        }

        let root = response.jsonObject ?? [:]
        let dataObj = (root["data"] as? [String: Any]) ?? root
        let obj = (dataObj["obligation"] as? [String: Any])
            ?? (dataObj["submission"] as? [String: Any])
            ?? (root["submission"] as? [String: Any])
            ?? (root["obligation"] as? [String: Any])
            ?? dataObj
        var item = Self.parseObligationItem(obj, fallbackRoot: dataObj, fallback: fallback)
        if item.sections.isEmpty && !sections.isEmpty {
            item.sections = sections
        }
        if item.formPayload.isEmpty {
            item.formPayload = formPayload
        }
        return .success(item, statusCode: response.statusCode)
    }

    /// Distinguishes `WORK_REPORT_DEADLINE_PASSED` from `WORK_REPORT_VERSION_CONFLICT` on HTTP 409.
    public static func handleWorkReportConflictResponse<T>(_ response: BackendHttpResponse) -> MiniBiApiResult<T> {
        let rawCode = (response.errorCode ?? response.jsonObject?.optString("code", "error_code") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        if rawCode == WorkReportsContract.codeDeadlinePassed {
            return .failure(
                message: WorkReportsContract.deadlinePassedMessageVi,
                httpStatus: 409,
                errorCode: WorkReportsContract.codeDeadlinePassed
            )
        }

        let resolvedConflictCode = rawCode.isEmpty ? WorkReportsContract.codeVersionConflict : rawCode
        let conflictMessage = response.errorMessage
            ?? "Báo cáo đã được cập nhật ở phiên làm việc khác. Đã tải lại phiên bản mới nhất."
        return .failure(
            message: conflictMessage,
            httpStatus: 409,
            errorCode: resolvedConflictCode
        )
    }

    // MARK: - 3. Reviews & Templates & Analytics

    public func fetchPendingReviews(
        status: String = "SUBMITTED",
        templateId: String? = nil,
        cursor: String? = nil,
        page: Int = 1,
        pageSize: Int = 15
    ) async -> MiniBiApiResult<[WorkReportReviewItem]> {
        let safePageSize = min(max(pageSize, 1), 100)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page_size", value: String(safePageSize))
        ]
        let cleanTemplateId = (templateId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanTemplateId.isEmpty {
            queryItems.append(URLQueryItem(name: "template_id", value: cleanTemplateId))
        }
        let cleanCursor = (cursor ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanCursor.isEmpty {
            queryItems.append(URLQueryItem(name: "cursor", value: cleanCursor))
        }
        let response = await httpClient.request(
            method: "GET",
            path: "/api/work-reports/reviews",
            queryItems: queryItems
        )
        if response.statusCode == 403 || response.statusCode == 404 {
            lastPendingReviewsNextCursor = nil
            lastPendingReviewsHasMore = false
            return .success([], statusCode: response.statusCode)
        }
        guard response.isSuccess else {
            return .failure(
                message: response.errorMessage ?? "Không tải được danh sách báo cáo chờ duyệt.",
                httpStatus: response.statusCode,
                errorCode: response.errorCode
            )
        }

        let root = response.jsonObject ?? [:]
        let dataObj = (root["data"] as? [String: Any]) ?? root
        let rawList = root.optObjectArray("items")
            .ifEmpty(root.optObjectArray("data"))
            .ifEmpty(root.optObjectArray("reviews"))
            .ifEmpty(dataObj.optObjectArray("reviews"))
            .ifEmpty(dataObj.optObjectArray("items"))

        let rawNextCursor = dataObj.optString("next_cursor")
            .ifEmpty(root.optString("next_cursor"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let nextCursor: String? = (rawNextCursor.isEmpty || rawNextCursor.lowercased() == "null") ? nil : rawNextCursor
        let hasMore = dataObj.optBool("has_more", defaultValue: root.optBool("has_more", defaultValue: nextCursor != nil))
            && nextCursor != nil
        lastPendingReviewsNextCursor = nextCursor
        lastPendingReviewsHasMore = hasMore

        let items = rawList.map { Self.parseReviewItem($0) }
        return .success(items, statusCode: response.statusCode)
    }

    public func decideReview(
        submissionId: Int64,
        decision: String,
        comment: String,
        expectedVersion: Int
    ) async -> MiniBiApiResult<Bool> {
        await decideReview(
            submissionIdUuid: String(submissionId),
            decision: decision,
            comment: comment,
            expectedVersion: expectedVersion
        )
    }

    public func decideReview(
        submissionIdUuid: String,
        decision: String,
        comment: String,
        expectedVersion: Int
    ) async -> MiniBiApiResult<Bool> {
        let normalizedDecision: String = {
            let upper = decision.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if upper == "APPROVE" || upper == "APPROVED" { return "APPROVED" }
            if upper == "REJECT" || upper == "REJECTED" { return "REJECTED" }
            return upper
        }()
        let cleanComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        let idempotencyKey = UUID().uuidString.lowercased()
        let body: [String: Any] = [
            "decision": normalizedDecision,
            "reason": cleanComment.isEmpty ? NSNull() : cleanComment,
            "expected_version": max(1, expectedVersion),
            "idempotency_key": idempotencyKey
        ]
        let encoded = submissionIdUuid.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? submissionIdUuid
        let response = await httpClient.request(
            method: "POST",
            path: "/api/work-reports/reviews/\(encoded)/decision",
            jsonBody: body,
            additionalHeaders: ["Idempotency-Key": idempotencyKey]
        )
        guard response.isSuccess else {
            return .failure(
                message: response.errorMessage ?? "Xử lý duyệt báo cáo thất bại.",
                httpStatus: response.statusCode,
                errorCode: response.errorCode
            )
        }
        return .success(true, statusCode: response.statusCode)
    }

    public func fetchSelectableTemplates() async -> MiniBiApiResult<[WorkReportTemplateOption]> {
        var response = await httpClient.request(method: "GET", path: "/api/work-reports/templates/selectable")
        if response.statusCode == 404 {
            response = await httpClient.request(method: "GET", path: "/api/work-reports/templates")
        }
        if response.statusCode == 403 || response.statusCode == 404 {
            return .success([], statusCode: response.statusCode)
        }
        guard response.isSuccess else {
            return .failure(
                message: response.errorMessage ?? "Không tải được danh sách biểu mẫu báo cáo.",
                httpStatus: response.statusCode,
                errorCode: response.errorCode
            )
        }
        let root = response.jsonObject ?? [:]
        let rawList = root.optObjectArray("items")
            .ifEmpty(root.optObjectArray("data"))
            .ifEmpty(root.optObjectArray("templates"))
            .ifEmpty((root["data"] as? [String: Any])?.optObjectArray("templates") ?? [])

        let items = rawList.compactMap { obj -> WorkReportTemplateOption? in
            let code = obj.optString("code", "template_code", "template_id", "id")
            guard !code.isEmpty else { return nil }
            let name = obj.optString("name", "template_name", "title", defaultValue: code)
            let periodType = obj.optString("period_type", defaultValue: "WEEKLY")
            return WorkReportTemplateOption(code: code, name: name, periodType: periodType)
        }
        return .success(items, statusCode: response.statusCode)
    }

    public func fetchAnalyticsSnapshot(
        templateCode: String? = nil,
        periodType: String? = nil,
        periodKey: String? = nil
    ) async -> MiniBiApiResult<WorkReportsAnalyticsSnapshot> {
        var queryItems: [URLQueryItem] = []
        if let templateCode, !templateCode.isEmpty {
            queryItems.append(URLQueryItem(name: "template_code", value: templateCode))
        }
        if let periodType, !periodType.isEmpty {
            queryItems.append(URLQueryItem(name: "period_type", value: periodType))
        }
        if let periodKey, !periodKey.isEmpty {
            queryItems.append(URLQueryItem(name: "period_key", value: periodKey))
        }

        var response = await httpClient.request(
            method: "GET",
            path: "/api/work-reports/analytics/overview",
            queryItems: queryItems
        )
        if response.statusCode == 404 {
            response = await httpClient.request(
                method: "GET",
                path: "/api/work-reports/analytics/summary",
                queryItems: queryItems
            )
        }
        if response.statusCode == 403 || response.statusCode == 404 {
            return .success(WorkReportsAnalyticsSnapshot(), statusCode: response.statusCode)
        }
        guard response.isSuccess else {
            return .failure(
                message: response.errorMessage ?? "Không tải được thống kê tổng hợp báo cáo công việc.",
                httpStatus: response.statusCode,
                errorCode: response.errorCode
            )
        }

        let root = response.jsonObject ?? [:]
        let dataObj = (root["data"] as? [String: Any]) ?? root
        let kpiObj = (dataObj["summary"] as? [String: Any]) ?? (dataObj["kpis"] as? [String: Any]) ?? dataObj

        let totalOb = kpiObj.optInt("expected_count", "total_obligations", "total")
        let submittedCount = kpiObj.optInt("submitted_count", "submitted")
        let approvedCount = kpiObj.optInt("approved_count", "approved")
        let rejectedCount = kpiObj.optInt("rejected_count", "rejected")
        let overdueCount = kpiObj.optInt("overdue_count", "overdue")
        let completionRate = kpiObj.optDouble("completion_rate", "submitted_rate")
        let onTimeRate = kpiObj.optDouble("approval_rate", "on_time_rate", "ontime_rate")

        let byUnitRaw = dataObj.optObjectArray("by_unit").ifEmpty(dataObj.optObjectArray("units"))
        let byUnit: [WorkReportAnalyticsGroupRow] = byUnitRaw.enumerated().map { idx, u in
            WorkReportAnalyticsGroupRow(
                id: u.optString("org_unit_id", "unit_code", "id", defaultValue: "unit_\(idx)"),
                groupLabel: u.optString("unit_name", "label", "name", defaultValue: "Đơn vị \(idx + 1)"),
                totalObligations: u.optInt("expected_count", "total_obligations", "total"),
                submittedCount: u.optInt("submitted_count", "submitted"),
                approvedCount: u.optInt("approved_count", "approved"),
                overdueCount: u.optInt("overdue_count", "overdue"),
                completionRate: u.optDouble("completion_rate")
            )
        }

        let byTemplateRaw = dataObj.optObjectArray("by_template").ifEmpty(dataObj.optObjectArray("templates"))
        let byTemplate: [WorkReportAnalyticsGroupRow] = byTemplateRaw.enumerated().map { idx, t in
            WorkReportAnalyticsGroupRow(
                id: t.optString("template_code", "id", defaultValue: "tpl_\(idx)"),
                groupLabel: t.optString("template_name", "label", "name", defaultValue: "Mẫu \(idx + 1)"),
                totalObligations: t.optInt("expected_count", "total_obligations", "total"),
                submittedCount: t.optInt("submitted_count", "submitted"),
                approvedCount: t.optInt("approved_count", "approved"),
                overdueCount: t.optInt("overdue_count", "overdue"),
                completionRate: t.optDouble("completion_rate")
            )
        }

        let snapshot = WorkReportsAnalyticsSnapshot(
            kpis: WorkReportAnalyticsKpis(
                totalObligations: totalOb,
                submittedCount: submittedCount,
                approvedCount: approvedCount,
                rejectedCount: rejectedCount,
                overdueCount: overdueCount,
                completionRate: completionRate,
                onTimeRate: onTimeRate
            ),
            byUnit: byUnit,
            byTemplate: byTemplate
        )
        return .success(snapshot, statusCode: response.statusCode)
    }

    // MARK: - 4. Dashboard Overview & Workforce Deep Metrics & Team & Duplicate CCCD

    public static func buildWorkforceDeepQueryItems(startDate: String?, endDate: String?) -> [URLQueryItem] {
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "mode", value: "deep")]
        let cleanStart = (startDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEnd = (endDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanStart.isEmpty && cleanEnd.isEmpty {
            queryItems.append(URLQueryItem(name: "range", value: "all"))
        } else {
            if !cleanStart.isEmpty {
                queryItems.append(URLQueryItem(name: "from", value: cleanStart))
            }
            if !cleanEnd.isEmpty {
                queryItems.append(URLQueryItem(name: "to", value: cleanEnd))
            }
        }
        return queryItems
    }

    public static let canonicalTeamCodeMap: [String: String] = [
        "__system_vendor__": "__system_vendor__",
        "tài khoản nhà cung cấp": "__system_vendor__",
        "nhóm hệ thống vendor": "__system_vendor__",
        "hệ thống vendor": "__system_vendor__",
        "hungyen": "hungyen",
        "nhóm hưng yên": "hungyen",
        "hưng yên": "hungyen",
        "team hưng yên": "hungyen",
        "marketing": "marketing",
        "bộ phận marketing": "marketing",
        "nhóm marketing": "marketing",
        "team marketing": "marketing",
        "team1": "TEAM1",
        "team 1": "TEAM1",
        "nhóm 1": "TEAM1",
        "nhóm tuyển dụng 1": "TEAM1",
        "team2": "TEAM2",
        "team 2": "TEAM2",
        "nhóm 2": "TEAM2",
        "nhóm tuyển dụng 2": "TEAM2",
        "team3": "TEAM3",
        "team 3": "TEAM3",
        "nhóm 3": "TEAM3",
        "nhóm tuyển dụng 3": "TEAM3",
        "team4": "TEAM4",
        "team 4": "TEAM4",
        "nhóm 4": "TEAM4",
        "nhóm tuyển dụng 4": "TEAM4",
        "team5": "TEAM5",
        "team 5": "TEAM5",
        "nhóm 5": "TEAM5",
        "nhóm tuyển dụng 5": "TEAM5",
        "team6": "TEAM6",
        "team 6": "TEAM6",
        "nhóm 6": "TEAM6",
        "nhóm tuyển dụng 6": "TEAM6",
        "team7": "TEAM7",
        "team 7": "TEAM7",
        "nhóm 7": "TEAM7",
        "nhóm tuyển dụng 7": "TEAM7",
        "unknown": "unknown",
        "chưa gán nhóm": "unknown"
    ]

    public static func resolveCanonicalTeamCode(rawKey: String, rawDisplay: String) -> String {
        let keyTrim = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let dispTrim = rawDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
        let keyLower = keyTrim.lowercased()
        let dispLower = dispTrim.lowercased()
        if let mapped = canonicalTeamCodeMap[keyLower] { return mapped }
        if let mapped = canonicalTeamCodeMap[dispLower] { return mapped }
        let decoded = decodeTeamBucketCode(keyTrim)
        let decodedLower = decoded.lowercased()
        if let mapped = canonicalTeamCodeMap[decodedLower] { return mapped }
        if decodedLower.hasPrefix("team"), decodedLower.count >= 5 {
            let suffix = decoded.dropFirst(4).trimmingCharacters(in: CharacterSet(charactersIn: " _-"))
            if !suffix.isEmpty, suffix.allSatisfy(\.isNumber) {
                return "TEAM\(suffix)"
            }
            return decoded.uppercased()
        }
        for candidate in [dispLower, keyLower] {
            for prefix in ["nhóm tuyển dụng ", "nhóm ", "team "] where candidate.hasPrefix(prefix) {
                let suffix = candidate.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
                if !suffix.isEmpty, suffix.allSatisfy(\.isNumber) {
                    return "TEAM\(suffix)"
                }
            }
        }
        return decoded.isEmpty ? "unknown" : decoded
    }

    public static func candidateTeamCodes(
        rawKey: String,
        rawDisplay: String = "",
        dynamicMap: [String: String] = [:]
    ) -> [String] {
        let cleanRaw = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let decoded = decodeTeamBucketCode(cleanRaw)
        let cleanDisp = rawDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
        var candidates: [String] = []
        var seen = Set<String>()

        func appendCandidate(_ raw: String?) {
            guard let raw else { return }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("team.") else { return }
            if !seen.contains(trimmed) {
                seen.insert(trimmed)
                candidates.append(trimmed)
            }
        }

        appendCandidate(dynamicMap[cleanRaw.lowercased()])
        appendCandidate(dynamicMap[decoded.lowercased()])
        if !cleanDisp.isEmpty {
            appendCandidate(dynamicMap[cleanDisp.lowercased()])
        }
        let resolved = resolveCanonicalTeamCode(rawKey: decoded, rawDisplay: cleanDisp)
        appendCandidate(resolved)
        appendCandidate(decoded)
        if decoded.lowercased() != "unknown" && decoded.lowercased() != "__system_vendor__" {
            appendCandidate(decoded.uppercased())
            appendCandidate(decoded.lowercased())
        }
        if candidates.isEmpty {
            appendCandidate("unknown")
        }
        return candidates
    }

    public func fetchAdminTeamCodeMap(canManageTeamCatalog: Bool) async -> [String: String] {
        let res = await fetchAdminTeamCatalogMetadata(canManageTeamCatalog: canManageTeamCatalog)
        return res.map
    }

    private func fetchAdminTeamCatalogMetadata(
        canManageTeamCatalog: Bool
    ) async -> (map: [String: String], verifiedCodes: Set<String>) {
        let defaultMap = Self.canonicalTeamCodeMap
        let defaultVerified = Set(defaultMap.values.map { $0.lowercased() })
        guard canManageTeamCatalog else {
            return (defaultMap, defaultVerified)
        }
        let client = self.httpClient
        return await reportingCoalescer.fetchAdminTeamMap(
            canFetchRemote: true,
            defaultMap: defaultMap
        ) {
            var map = defaultMap
            var verified = defaultVerified
            let resp = await client.request(
                method: "GET",
                path: "/api/admin/catalog/teams",
                queryItems: [
                    URLQueryItem(name: "include_inactive", value: "true"),
                    URLQueryItem(name: "page", value: "1"),
                    URLQueryItem(name: "page_size", value: "100")
                ]
            )
            guard resp.isSuccess, let root = resp.jsonObject else {
                return ( [:], verified )
            }
            let dataObj = (root["data"] as? [String: Any]) ?? root
            let items = root.optObjectArray("items", "teams")
                .ifEmpty(dataObj.optObjectArray("items", "teams"))
            for item in items {
                let teamId = item.optString("team_id", "id")
                let teamCode = item.optString("team_code", "code", "key")
                let displayName = item.optString("display_name", "display", "name", "team_name")
                guard !teamCode.isEmpty else { continue }
                verified.insert(teamCode.lowercased())
                map[teamCode.lowercased()] = teamCode
                map[Self.encodeTeamBucketKey(teamCode).lowercased()] = teamCode
                if !teamId.isEmpty {
                    map[teamId.lowercased()] = teamCode
                    map[Self.encodeTeamBucketKey(teamId).lowercased()] = teamCode
                }
                if !displayName.isEmpty {
                    map[displayName.lowercased()] = teamCode
                }
            }
            return (map, verified)
        }
    }

    public static func defaultTeamDisplayName(for bucketKeyOrCode: String) -> String {
        let decoded = decodeTeamBucketCode(bucketKeyOrCode).trimmingCharacters(in: .whitespacesAndNewlines)
        switch decoded.lowercased() {
        case "unknown", "":
            return "Chưa gán nhóm"
        case "__system_vendor__":
            return "Tài khoản nhà cung cấp"
        case "hungyen":
            return "Nhóm Hưng Yên"
        case "marketing":
            return "Bộ phận Marketing"
        default:
            if decoded.lowercased().hasPrefix("team"), decoded.count > 4 {
                let suffix = decoded.dropFirst(4).trimmingCharacters(in: CharacterSet(charactersIn: " _-"))
                if !suffix.isEmpty, suffix.allSatisfy(\.isNumber) {
                    return "Nhóm Tuyển dụng \(suffix)"
                }
            }
            return decoded
        }
    }

    public static func leaveCategoryLabelVi(_ key: String, fallback: String = "") -> String {
        let cleanFallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowerKey = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !cleanFallback.isEmpty && cleanFallback.lowercased() != lowerKey {
            return cleanFallback
        }
        switch lowerKey {
        case "salary_benefits":
            return "Lương & chế độ đãi ngộ"
        case "work_environment":
            return "Môi trường & điều kiện làm việc"
        case "personal_family":
            return "Lý do cá nhân / gia đình"
        case "health_medical":
            return "Sức khỏe / y tế"
        case "management_team":
            return "Quản lý / nội bộ nhóm"
        case "contract_end":
            return "Hết hạn hợp đồng / cắt giảm"
        case "disciplinary_violation":
            return "Vi phạm kỷ luật / tự ý nghỉ"
        case "other":
            return "Lý do khác"
        case "unknown":
            return "Chưa ghi nhận lý do"
        default:
            return cleanFallback.isEmpty ? key : cleanFallback
        }
    }

    private func fetchCoalescedWorkforceDeepResponse(
        startDate: String?,
        endDate: String?
    ) async -> BackendHttpResponse {
        let cleanStart = (startDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEnd = (endDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let key = "wf_deep|\(cleanStart)|\(cleanEnd)"
        let queryItems = Self.buildWorkforceDeepQueryItems(startDate: cleanStart, endDate: cleanEnd)
        let client = self.httpClient
        return await reportingCoalescer.fetchWorkforceDeep(key: key) {
            await client.request(
                method: "GET",
                path: "/api/reporting/workforce-deep",
                queryItems: queryItems
            )
        }
    }

    public static func encodeTeamBucketKey(_ rawTeamCodeOrBucketKey: String) -> String {
        let trimmed = rawTeamCodeOrBucketKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "unknown" }
        if trimmed == "unknown" || trimmed.hasPrefix("team.") {
            return trimmed
        }
        let b64 = Data(trimmed.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "team.\(b64)"
    }

    public static func decodeTeamBucketCode(_ rawTeamCodeOrBucketKey: String) -> String {
        let trimmed = rawTeamCodeOrBucketKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("team.") else { return trimmed }
        var b64 = String(trimmed.dropFirst("team.".count))
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let rem = b64.count % 4
        if rem > 0 {
            b64 += String(repeating: "=", count: 4 - rem)
        }
        if let data = Data(base64Encoded: b64),
           let decoded = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !decoded.isEmpty {
            return decoded
        }
        return trimmed
    }

    /// Parses bucket entries from `/api/reporting/team-report` or `/api/reporting/workforce-deep`.
    /// Strictly preserves `nil` for `onCount`, `offCount`, `unconfirmedCount` when those keys are absent in JSON —
    /// NEVER defaults `onCount` to `count`!
    public static func parseReportingBucketEntries(
        from report: [String: Any],
        keys: [String]
    ) -> [(key: String, display: String, totalCount: Int, onCount: Int?, offCount: Int?, unconfirmedCount: Int?)] {
        for key in keys {
            if let dict = report[key] as? [String: Any] {
                var rows: [(key: String, display: String, totalCount: Int, onCount: Int?, offCount: Int?, unconfirmedCount: Int?)] = []
                for (mapKey, val) in dict {
                    if let obj = val as? [String: Any] {
                        let count = obj.optInt("recruitedCount", "recruited_count", "total_count", "totalCount", "eligible_episode_count", "count", "total")
                        guard count > 0 else { continue }
                        let itemKey = obj.optString("key", "id", "code", defaultValue: mapKey)
                        let display = normalizeBucketDisplay(
                            rawDisplay: obj.optString("display", "displayName", "display_name", "label", "name", defaultValue: itemKey),
                            fallbackKey: itemKey
                        )
                        let onCnt = obj.optNullableInt("on_count", "onCount", "active_count")
                        let offCnt = obj.optNullableInt("off_count", "offCount", "inactive_count")
                        let unconfCnt = obj.optNullableInt("unconfirmed_count", "unconfirmedCount")
                        rows.append((itemKey, display, count, onCnt, offCnt, unconfCnt))
                    } else if let num = val as? NSNumber, num.intValue > 0 {
                        let display = normalizeBucketDisplay(rawDisplay: mapKey, fallbackKey: mapKey)
                        rows.append((mapKey, display, num.intValue, nil, nil, nil))
                    }
                }
                return rows.sorted { $0.totalCount != $1.totalCount ? $0.totalCount > $1.totalCount : $0.display < $1.display }
            }
            let arr = report.optObjectArray(key)
            if !arr.isEmpty {
                let parsed = arr.compactMap { obj -> (key: String, display: String, totalCount: Int, onCount: Int?, offCount: Int?, unconfirmedCount: Int?)? in
                    let count = obj.optInt("recruitedCount", "recruited_count", "total_count", "totalCount", "eligible_episode_count", "count", "total")
                    guard count > 0 else { return nil }
                    let itemKey = obj.optString("key", "project_id", "recruiter_id", "code", "id", defaultValue: "unknown")
                    let display = normalizeBucketDisplay(
                        rawDisplay: obj.optString("display", "displayName", "display_name", "project_display", "recruiter_display", "label", "name", defaultValue: itemKey),
                        fallbackKey: itemKey
                    )
                    let onCnt = obj.optNullableInt("on_count", "onCount", "active_count")
                    let offCnt = obj.optNullableInt("off_count", "offCount", "inactive_count")
                    let unconfCnt = obj.optNullableInt("unconfirmed_count", "unconfirmedCount")
                    return (itemKey, display, count, onCnt, offCnt, unconfCnt)
                }
                return parsed.sorted { $0.totalCount != $1.totalCount ? $0.totalCount > $1.totalCount : $0.display < $1.display }
            }
        }
        return []
    }

    private static func normalizeBucketDisplay(rawDisplay: String, fallbackKey: String) -> String {
        let trimmed = rawDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.isEmpty ? fallbackKey.trimmingCharacters(in: .whitespacesAndNewlines) : trimmed
        switch candidate.lowercased() {
        case "hrp":
            return "Nội bộ HRP"
        case "vendor":
            return "Vendor"
        case "thoi_vu", "seasonal":
            return "Thời vụ"
        case "chinh_thuc", "official":
            return "Chính thức"
        case "unknown":
            return "Chưa phân loại"
        default:
            return candidate
        }
    }

    public static func buildBiBucketItems(
        from entries: [(key: String, display: String, totalCount: Int, onCount: Int?, offCount: Int?, unconfirmedCount: Int?)],
        totalDenominator: Int = 0
    ) -> [BiBucketItem] {
        let sorted = entries.sorted { $0.totalCount != $1.totalCount ? $0.totalCount > $1.totalCount : $0.display < $1.display }
        let sumCounts = sorted.reduce(0) { $0 + $1.totalCount }
        let denom = max(1, totalDenominator > 0 ? totalDenominator : sumCounts)
        return sorted.map { item in
            BiBucketItem(
                key: item.key,
                display: item.display,
                count: item.totalCount,
                sharePct: Double(item.totalCount) * 100.0 / Double(denom),
                onCount: item.onCount,
                unconfirmedCount: item.unconfirmedCount,
                offCount: item.offCount
            )
        }
    }

    private func fetchSingleTeamPeriodReport(
        canonicalCode: String,
        rawKey: String,
        rawDisplay: String = "",
        dynamicMap: [String: String] = [:],
        startDate: String,
        endDate: String
    ) async -> [String: Any]? {
        let candidates = Self.candidateTeamCodes(
            rawKey: rawKey.isEmpty ? canonicalCode : rawKey,
            rawDisplay: rawDisplay,
            dynamicMap: dynamicMap
        )
        for candidate in candidates {
            let bucketKey = Self.encodeTeamBucketKey(candidate)
            var q: [URLQueryItem] = [
                URLQueryItem(name: "bucket_key", value: bucketKey),
                URLQueryItem(name: "limit", value: "1")
            ]
            if !startDate.isEmpty { q.append(URLQueryItem(name: "from", value: startDate)) }
            if !endDate.isEmpty { q.append(URLQueryItem(name: "to", value: endDate)) }
            let resp = await httpClient.request(
                method: "GET",
                path: "/api/reporting/team-report",
                queryItems: q
            )
            if resp.isSuccess, let root = resp.jsonObject, root["bucket"] != nil || root["report"] != nil {
                return root
            }
            if resp.statusCode == 401 || resp.statusCode == 403 {
                break
            }
        }
        return nil
    }

    private func fetchCoalescedPeriodAggregation(
        teamBucketsRaw: [[String: Any]],
        startDate: String,
        endDate: String,
        canManageTeamCatalog: Bool = false
    ) async -> PeriodAllScopeAggregation? {
        let cleanStart = startDate.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEnd = endDate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanStart.isEmpty || !cleanEnd.isEmpty else { return nil }
        let cacheKey = "period_agg|\(cleanStart)|\(cleanEnd)"
        let dynamicMap = await fetchAdminTeamCodeMap(canManageTeamCatalog: canManageTeamCatalog)

        struct TeamSeed: Sendable {
            let rawKey: String
            let display: String
            let canonicalCode: String
        }

        var seeds: [TeamSeed] = []
        var seenCanonical: Set<String> = []
        for (idx, b) in teamBucketsRaw.enumerated() {
            let rawKey = b.optString("key", "team_id", "code", defaultValue: "team_\(idx)")
            let display = b.optString("display", "team_name", "name", defaultValue: rawKey)
            let canonical = Self.candidateTeamCodes(rawKey: rawKey, rawDisplay: display, dynamicMap: dynamicMap).first
                ?? Self.resolveCanonicalTeamCode(rawKey: rawKey, rawDisplay: display)
            let dedupKey = canonical.lowercased()
            if !seenCanonical.contains(dedupKey) {
                seenCanonical.insert(dedupKey)
                seeds.append(TeamSeed(rawKey: rawKey, display: display, canonicalCode: canonical))
            }
        }
        if !seenCanonical.contains("unknown") {
            seenCanonical.insert("unknown")
            seeds.append(TeamSeed(rawKey: "unknown", display: "Chưa gán nhóm", canonicalCode: "unknown"))
        }

        return await reportingCoalescer.fetchPeriodAggregation(key: cacheKey) { [weak self] in
            guard let self else { return nil }

            struct TeamPeriodSlice {
                let seed: TeamSeed
                let report: [String: Any]
            }

            var slices: [TeamPeriodSlice] = []
            let chunkSize = 4
            var offset = 0
            while offset < seeds.count {
                let endIdx = min(offset + chunkSize, seeds.count)
                let batch = Array(seeds[offset..<endIdx])
                let batchResults = await withTaskGroup(of: TeamPeriodSlice?.self, returning: [TeamPeriodSlice].self) { group in
                    for seed in batch {
                        group.addTask {
                            if let rep = await self.fetchSingleTeamPeriodReport(
                                canonicalCode: seed.canonicalCode,
                                rawKey: seed.rawKey,
                                rawDisplay: seed.display,
                                dynamicMap: dynamicMap,
                                startDate: cleanStart,
                                endDate: cleanEnd
                            ) {
                                return TeamPeriodSlice(seed: seed, report: rep)
                            }
                            return nil
                        }
                    }
                    var collected: [TeamPeriodSlice] = []
                    for await item in group {
                        if let item { collected.append(item) }
                    }
                    return collected
                }
                slices.append(contentsOf: batchResults)
                offset = endIdx
            }

            guard !slices.isEmpty else { return nil }

            struct MutableBucket {
                var key: String
                var display: String
                var totalCount: Int = 0
                var onCount: Int? = nil
                var offCount: Int? = nil
                var unconfirmedCount: Int? = nil
            }

            var totalWorkers = 0
            var activeCount = 0
            var inactiveCount = 0
            var unconfirmedCount = 0

            var projectMap: [String: MutableBucket] = [:]
            var recruiterMap: [String: MutableBucket] = [:]
            var providerMap: [String: MutableBucket] = [:]
            var combinedByDate: [String: Int] = [:]
            var teamRows: [TeamSummaryRow] = []
            var managerRows: [PersonPerformanceRow] = []
            var teamDistRaw: [(key: String, label: String, count: Int)] = []

            for slice in slices {
                let rootObj = slice.report
                let rep = (rootObj["report"] as? [String: Any]) ?? rootObj
                let bucketObj = (rootObj["bucket"] as? [String: Any]) ?? (rep["team"] as? [String: Any]) ?? [:]
                let detailObj = (rootObj["detail"] as? [String: Any]) ?? [:]
                let wfSnapObj = ((rootObj["workforce"] as? [String: Any])?["snapshot"] as? [String: Any])
                    ?? (rep["summary"] as? [String: Any])
                    ?? [:]

                let tTotal = rep.optInt("recruitedTotal", "recruited_total", defaultValue: detailObj.optInt("total", defaultValue: wfSnapObj.optInt("total_count", "totalCount", "total")))
                // Strictly nullable: NEVER default onCount to tTotal!
                let tOn = wfSnapObj.optNullableInt("onCount", "on_count", "active_count")
                let tOff = wfSnapObj.optNullableInt("offCount", "off_count", "inactive_count")
                let tUnconf = wfSnapObj.optNullableInt("unconfirmedCount", "unconfirmed_count")

                totalWorkers += tTotal
                if let tOn { activeCount += tOn }
                if let tOff { inactiveCount += tOff }
                if let tUnconf { unconfirmedCount += tUnconf }

                let sliceRows = Self.parseTeamDrillDownRows(from: detailObj, fallbackReport: rep)
                let sliceByDate = WorkReportsContract.extractByDateCounts(from: rep, fallbackRows: sliceRows)
                for (dateIso, cnt) in sliceByDate {
                    combinedByDate[dateIso, default: 0] += cnt
                }

                for p in Self.parseReportingBucketEntries(from: rep, keys: ["byProject", "by_project"]) {
                    let normKey = p.key.lowercased()
                    var cur = projectMap[normKey] ?? MutableBucket(key: p.key, display: p.display)
                    cur.totalCount += p.totalCount
                    if let v = p.onCount { cur.onCount = (cur.onCount ?? 0) + v }
                    if let v = p.offCount { cur.offCount = (cur.offCount ?? 0) + v }
                    if let v = p.unconfirmedCount { cur.unconfirmedCount = (cur.unconfirmedCount ?? 0) + v }
                    projectMap[normKey] = cur
                }

                var teamMembers: [PersonPerformanceRow] = []
                for r in Self.parseReportingBucketEntries(from: rep, keys: ["byRecruiter", "by_recruiter"]) {
                    let normKey = r.key.lowercased()
                    var cur = recruiterMap[normKey] ?? MutableBucket(key: r.key, display: r.display)
                    cur.totalCount += r.totalCount
                    if let v = r.onCount { cur.onCount = (cur.onCount ?? 0) + v }
                    if let v = r.offCount { cur.offCount = (cur.offCount ?? 0) + v }
                    if let v = r.unconfirmedCount { cur.unconfirmedCount = (cur.unconfirmedCount ?? 0) + v }
                    recruiterMap[normKey] = cur

                    if slice.seed.canonicalCode != "unknown" {
                        let mOn = r.onCount ?? 0
                        let mOff = r.offCount ?? 0
                        teamMembers.append(
                            PersonPerformanceRow(
                                id: "\(slice.seed.rawKey)_\(r.key)",
                                code: r.key,
                                name: r.display,
                                totalCount: r.totalCount,
                                activeCount: mOn,
                                inactiveCount: mOff,
                                activeRatePct: (r.onCount != nil && r.totalCount > 0) ? (Double(mOn) * 100.0 / Double(r.totalCount)) : 0.0
                            )
                        )
                    }
                }
                teamMembers.sort { $0.totalCount > $1.totalCount }

                for pr in Self.parseReportingBucketEntries(from: rep, keys: ["byProvider", "by_provider", "byProviderType", "by_provider_type"]) {
                    let normKey = pr.key.lowercased()
                    var cur = providerMap[normKey] ?? MutableBucket(key: pr.key, display: pr.display)
                    cur.totalCount += pr.totalCount
                    if let v = pr.onCount { cur.onCount = (cur.onCount ?? 0) + v }
                    if let v = pr.offCount { cur.offCount = (cur.offCount ?? 0) + v }
                    if let v = pr.unconfirmedCount { cur.unconfirmedCount = (cur.unconfirmedCount ?? 0) + v }
                    providerMap[normKey] = cur
                }

                let teamDisplay = bucketObj.optString("display", "displayName", "display_name", defaultValue: slice.seed.display)
                if tTotal > 0 || slice.seed.canonicalCode != "unknown" {
                    let safeOn = tOn ?? 0
                    let safeOff = tOff ?? 0
                    let rate = (tOn != nil && tTotal > 0) ? min(100.0, Double(safeOn) * 100.0 / Double(tTotal)) : 0.0
                    if tTotal > 0 {
                        managerRows.append(
                            PersonPerformanceRow(
                                id: slice.seed.rawKey,
                                code: slice.seed.canonicalCode,
                                name: teamDisplay,
                                totalCount: tTotal,
                                activeCount: min(tTotal, safeOn),
                                inactiveCount: min(tTotal, safeOff),
                                activeRatePct: rate
                            )
                        )
                        teamDistRaw.append((key: slice.seed.rawKey, label: teamDisplay, count: tTotal))
                    }
                    if slice.seed.canonicalCode != "unknown" || tTotal > 0 {
                        teamRows.append(
                            TeamSummaryRow(
                                id: slice.seed.rawKey,
                                teamCode: slice.seed.canonicalCode,
                                teamName: teamDisplay,
                                leaderName: "",
                                memberCount: teamMembers.count,
                                totalWorkers: tTotal,
                                activeWorkers: min(tTotal, safeOn),
                                inactiveWorkers: min(tTotal, safeOff),
                                newWorkers: 0,
                                activeRatePct: rate,
                                members: teamMembers
                            )
                        )
                    }
                }
            }

            let sortedProjectEntries = projectMap.values
                .filter { $0.totalCount > 0 }
                .sorted { $0.totalCount != $1.totalCount ? $0.totalCount > $1.totalCount : $0.display < $1.display }
            let sortedProjects = sortedProjectEntries.enumerated().map { idx, b in
                let pOn = b.onCount ?? 0
                let pOff = b.offCount ?? 0
                return ProjectBreakdownRow(
                    id: b.key.isEmpty ? "proj_\(idx)" : b.key,
                    projectName: b.display,
                    totalCount: b.totalCount,
                    activeCount: pOn,
                    inactiveCount: pOff,
                    newCount: 0,
                    activeSharePct: (b.onCount != nil && b.totalCount > 0) ? (Double(pOn) * 100.0 / Double(b.totalCount)) : 0.0
                )
            }

            let sortedRecruiterEntries = recruiterMap.values
                .filter { $0.totalCount > 0 }
                .sorted { $0.totalCount != $1.totalCount ? $0.totalCount > $1.totalCount : $0.display < $1.display }
            let sortedRecruiters = sortedRecruiterEntries.map { b in
                let rOn = b.onCount ?? 0
                let rOff = b.offCount ?? 0
                return PersonPerformanceRow(
                    id: b.key,
                    code: b.key,
                    name: b.display,
                    totalCount: b.totalCount,
                    activeCount: rOn,
                    inactiveCount: rOff,
                    activeRatePct: (b.onCount != nil && b.totalCount > 0) ? (Double(rOn) * 100.0 / Double(b.totalCount)) : 0.0
                )
            }

            managerRows.sort { $0.totalCount > $1.totalCount }
            teamRows.sort { $0.totalWorkers > $1.totalWorkers }

            let safeTotal = max(1, totalWorkers)
            let teamBuckets = teamDistRaw
                .sorted { $0.count > $1.count }
                .map { item in
                    DistributionBucket(
                        id: item.key,
                        label: item.label,
                        count: item.count,
                        percentage: Double(item.count) * 100.0 / Double(safeTotal)
                    )
                }

            let sortedProviderEntries = providerMap.values
                .filter { $0.totalCount > 0 }
                .sorted { $0.totalCount > $1.totalCount }
            let providerBuckets = sortedProviderEntries.map { b in
                DistributionBucket(
                    id: b.key,
                    label: b.display,
                    count: b.totalCount,
                    percentage: Double(b.totalCount) * 100.0 / Double(safeTotal)
                )
            }

            let byRecruiterItems = Self.buildBiBucketItems(
                from: sortedRecruiterEntries.map { ($0.key, $0.display, $0.totalCount, $0.onCount, $0.offCount, $0.unconfirmedCount) },
                totalDenominator: totalWorkers
            )
            let byProjectItems = Self.buildBiBucketItems(
                from: sortedProjectEntries.map { ($0.key, $0.display, $0.totalCount, $0.onCount, $0.offCount, $0.unconfirmedCount) },
                totalDenominator: totalWorkers
            )
            let byTeamItems = Self.buildBiBucketItems(
                from: teamDistRaw.map { ($0.key, $0.label, $0.count, nil, nil, nil) },
                totalDenominator: totalWorkers
            )
            let byProviderItems = Self.buildBiBucketItems(
                from: sortedProviderEntries.map { ($0.key, $0.display, $0.totalCount, $0.onCount, $0.offCount, $0.unconfirmedCount) },
                totalDenominator: totalWorkers
            )
            let hiringSummary = WorkReportsContract.computeHiringDaySummary(byDateCounts: combinedByDate)

            return PeriodAllScopeAggregation(
                totalWorkers: totalWorkers,
                activeCount: activeCount,
                inactiveCount: inactiveCount,
                unconfirmedCount: unconfirmedCount,
                projects: sortedProjects,
                recruiters: sortedRecruiters,
                managers: managerRows,
                teamBuckets: teamBuckets,
                providerBuckets: providerBuckets,
                teams: teamRows,
                byRecruiterItems: byRecruiterItems,
                byProjectItems: byProjectItems,
                byTeamItems: byTeamItems,
                byProviderItems: byProviderItems,
                hiringSummary: hiringSummary
            )
        }
    }

    public static func parseTeamDrillDownRows(
        from detailObj: [String: Any],
        fallbackReport: [String: Any] = [:]
    ) -> [TeamDrillDownItem] {
        let rawList = detailObj.optObjectArray("rows", "items")
            .ifEmpty(fallbackReport.optObjectArray("rows", "items"))
        return rawList.enumerated().map { idx, obj in
            let businessDate = WorkReportsContract.normalizeDateIso(
                obj.optString("businessDate", "business_date", "date", "report_date", "firstWorkDate", "first_work_date")
            )
            let firstWorkDate = WorkReportsContract.normalizeDateIso(
                obj.optString("firstWorkDate", "first_work_date", "ngay_vao_lam", defaultValue: businessDate)
            )
            let projectObj = obj["project"] as? [String: Any]
            let projectDisplay = projectObj?.optString("display", "display_name", "name")
                ?? obj.optString("projectDisplay", "project_display", "du_an", "project_name", "project", defaultValue: "Chưa phân dự án")
            let recruiterObj = obj["recruiter"] as? [String: Any]
            let recruiterDisplay = recruiterObj?.optString("display", "display_name", "name")
                ?? obj.optString("recruiterDisplay", "recruiter_display", "nguoi_tuyen", "recruiter_name", "recruiter", defaultValue: "Chưa gán người tuyển")
            let rawProvider = obj.optString("providerTypeDisplay", "provider_type_display", "providerType", "provider_type", "provider", defaultValue: "HRP")
            let providerDisplay: String = {
                switch rawProvider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "hrp", "nội bộ hrp":
                    return "Nội bộ HRP"
                case "vendor":
                    return "Vendor"
                default:
                    return rawProvider.isEmpty ? "Nội bộ HRP" : rawProvider
                }
            }()
            let rawEmp = obj.optString("employmentTypeDisplay", "employment_type_display", "employmentType", "employment_type", "labor_type_display", "labor_type", defaultValue: "Thời vụ")
            let empDisplay: String = {
                switch rawEmp.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "thoi_vu", "seasonal", "thời vụ":
                    return "Thời vụ"
                case "chinh_thuc", "official", "chính thức":
                    return "Chính thức"
                default:
                    return rawEmp.isEmpty ? "Thời vụ" : rawEmp
                }
            }()
            let count = max(1, obj.optInt("recruitedCount", "recruited_count", "count", "total", defaultValue: 1))
            let rowId = obj.optString("id", "row_id", defaultValue: "\(businessDate)_\(projectDisplay)_\(recruiterDisplay)_\(idx)")
            return TeamDrillDownItem(
                id: rowId,
                businessDate: businessDate,
                projectDisplay: projectDisplay,
                recruiterDisplay: recruiterDisplay,
                providerTypeDisplay: providerDisplay,
                employmentTypeDisplay: empDisplay,
                recruitedCount: count,
                firstWorkDate: firstWorkDate
            )
        }
    }

    public static func parseTeamReportSnapshot(
        from root: [String: Any],
        requestedBucketKey: String,
        knownBucketHint: BiBucketItem? = nil,
        isPeriodFiltered: Bool = false
    ) -> TeamReportSnapshot {
        let dataObj = (root["data"] as? [String: Any]) ?? root
        let repObj = (root["report"] as? [String: Any])
            ?? (dataObj["report"] as? [String: Any])
            ?? dataObj
        let bucketObj = (root["bucket"] as? [String: Any])
            ?? (dataObj["bucket"] as? [String: Any])
            ?? (repObj["team"] as? [String: Any])
            ?? [:]
        let detailObj = (root["detail"] as? [String: Any])
            ?? (dataObj["detail"] as? [String: Any])
            ?? [:]
        let wfObj = (root["workforce"] as? [String: Any])
            ?? (dataObj["workforce"] as? [String: Any])
            ?? [:]
        let wfSnapObj = (wfObj["snapshot"] as? [String: Any])
            ?? (repObj["summary"] as? [String: Any])
            ?? [:]

        let resolvedBucketKey = bucketObj.optString(
            "key",
            "bucketKey",
            "bucket_key",
            defaultValue: requestedBucketKey.isEmpty ? (knownBucketHint?.key ?? "unknown") : requestedBucketKey
        )
        let resolvedBucketDisplay: String = {
            let fromBucket = bucketObj.optString("display", "displayName", "display_name", "name", "label")
            if !fromBucket.isEmpty && fromBucket != resolvedBucketKey {
                return fromBucket
            }
            if let hint = knownBucketHint?.display, !hint.isEmpty {
                return hint
            }
            return !fromBucket.isEmpty ? fromBucket : defaultTeamDisplayName(for: resolvedBucketKey)
        }()

        let rows = parseTeamDrillDownRows(from: detailObj, fallbackReport: repObj)
        let nextCursor: String? = {
            let paginationObj = detailObj["pagination"] as? [String: Any]
            if let hasMore = (detailObj.optNullableInt("has_more", "hasMore") != nil ? detailObj.optBool("has_more", "hasMore") : paginationObj?.optBool("has_more", "hasMore")),
               hasMore == false {
                return nil
            }
            let raw = detailObj.optNullableString("nextCursor", "next_cursor")
                ?? paginationObj?.optNullableString("nextCursor", "next_cursor")
                ?? repObj.optNullableString("nextCursor", "next_cursor")
            guard let clean = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !clean.isEmpty else {
                return nil
            }
            return clean
        }()

        let recEntries = parseReportingBucketEntries(from: repObj, keys: ["byRecruiter", "by_recruiter"])
        let projEntries = parseReportingBucketEntries(from: repObj, keys: ["byProject", "by_project"])
        let empEntries = parseReportingBucketEntries(
            from: repObj,
            keys: ["byEmployment", "by_employment", "byEmploymentType", "by_employment_type", "byLaborType", "by_labor_type"]
        )
        let provEntries = parseReportingBucketEntries(
            from: repObj,
            keys: ["byProvider", "by_provider", "byProviderType", "by_provider_type"]
        )

        let totalRecruited: Int = {
            if let explicit = repObj.optNullableInt("recruitedTotal", "recruited_total", "total_recruited", "total") {
                return explicit
            }
            if let dTotal = detailObj.optNullableInt("total", "totalCount", "total_count") {
                return dTotal
            }
            if let sTotal = wfSnapObj.optNullableInt("eligible_episode_total", "eligibleEpisodeTotal", "total_count", "totalCount") {
                return sTotal
            }
            if !recEntries.isEmpty {
                return recEntries.reduce(0) { $0 + $1.totalCount }
            }
            if !projEntries.isEmpty {
                return projEntries.reduce(0) { $0 + $1.totalCount }
            }
            if !rows.isEmpty {
                return rows.reduce(0) { $0 + $1.recruitedCount }
            }
            return 0
        }()

        let byRecruiter = buildBiBucketItems(from: recEntries, totalDenominator: totalRecruited)
        let byProject = buildBiBucketItems(from: projEntries, totalDenominator: totalRecruited)
        let byEmployment = buildBiBucketItems(from: empEntries, totalDenominator: totalRecruited)
        let byProvider = buildBiBucketItems(from: provEntries, totalDenominator: totalRecruited)

        let activeRecruiterCount = repObj.optNullableInt("activeRecruiterCount", "active_recruiter_count")
            ?? (!byRecruiter.isEmpty
                ? byRecruiter.filter { $0.count > 0 }.count
                : Set(rows.map(\.recruiterDisplay).filter { !$0.isEmpty }).count)
        let activeProjectCount = repObj.optNullableInt("activeProjectCount", "active_project_count")
            ?? (!byProject.isEmpty
                ? byProject.filter { $0.count > 0 }.count
                : Set(rows.map(\.projectDisplay).filter { !$0.isEmpty }).count)

        let hiringSummary = WorkReportsContract.computeHiringDaySummary(fromReport: repObj, fallbackRows: rows)

        // Strictly never default workingCount to totalRecruited!
        let snapOn = wfSnapObj.optNullableInt("on_count", "onCount", "active_count")
        let snapWait = wfSnapObj.optNullableInt("unconfirmed_count", "unconfirmedCount", "waiting_count")
        let snapOff = wfSnapObj.optNullableInt("off_count", "offCount", "inactive_count")

        let workingCount: Int? = isPeriodFiltered ? snapOn : (snapOn ?? knownBucketHint?.onCount)
        let waitingCount: Int? = isPeriodFiltered ? snapWait : (snapWait ?? knownBucketHint?.unconfirmedCount)
        let leftCount: Int? = isPeriodFiltered ? snapOff : (snapOff ?? knownBucketHint?.offCount)

        return TeamReportSnapshot(
            bucketKey: resolvedBucketKey,
            bucketDisplay: resolvedBucketDisplay,
            totalRecruited: totalRecruited,
            rows: rows,
            nextCursor: nextCursor,
            activeRecruiterCount: activeRecruiterCount,
            activeProjectCount: activeProjectCount,
            activeHiringDays: hiringSummary.activeHiringDays,
            avgPerActiveDay: hiringSummary.avgPerActiveDay,
            peakDailyCount: hiringSummary.peakDailyCount,
            peakDateIso: hiringSummary.peakDateIso,
            workingCount: workingCount,
            waitingCount: waitingCount,
            leftCount: leftCount,
            byRecruiter: byRecruiter,
            byProject: byProject,
            byEmployment: byEmployment,
            byProvider: byProvider
        )
    }

    public func fetchTeamReportSnapshot(
        bucketKeyOrTeamCode: String,
        knownBucketHint: BiBucketItem? = nil,
        fromDate: String? = nil,
        toDate: String? = nil,
        limit: Int = 25,
        canManageTeamCatalog: Bool = false
    ) async -> MiniBiApiResult<TeamReportSnapshot> {
        let cleanFrom = (fromDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTo = (toDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let isPeriodFiltered = !cleanFrom.isEmpty || !cleanTo.isEmpty
        let catalogMeta = await fetchAdminTeamCatalogMetadata(canManageTeamCatalog: canManageTeamCatalog)
        let candidates = Self.candidateTeamCodes(
            rawKey: bucketKeyOrTeamCode,
            rawDisplay: knownBucketHint?.display ?? "",
            dynamicMap: catalogMeta.map
        )

        var lastResponse: BackendHttpResponse?
        var sawInvalidFilter = false

        for candidate in candidates {
            let encodedKey = Self.encodeTeamBucketKey(candidate)
            var queryItems: [URLQueryItem] = [
                URLQueryItem(name: "bucket_key", value: encodedKey),
                URLQueryItem(name: "limit", value: String(max(1, limit)))
            ]
            if !cleanFrom.isEmpty {
                queryItems.append(URLQueryItem(name: "from", value: cleanFrom))
            }
            if !cleanTo.isEmpty {
                queryItems.append(URLQueryItem(name: "to", value: cleanTo))
            }
            let resp = await httpClient.request(
                method: "GET",
                path: "/api/reporting/team-report",
                queryItems: queryItems
            )
            lastResponse = resp

            if resp.isSuccess, let root = resp.jsonObject {
                let dataObj = (root["data"] as? [String: Any]) ?? root
                if root["report"] != nil || root["bucket"] != nil || root["detail"] != nil
                    || dataObj["report"] != nil || dataObj["bucket"] != nil || dataObj["detail"] != nil
                    || dataObj["byRecruiter"] != nil || dataObj["by_recruiter"] != nil
                    || dataObj["byProject"] != nil || dataObj["by_project"] != nil
                    || dataObj["summary"] != nil || dataObj["rows"] != nil {
                    let snapshot = Self.parseTeamReportSnapshot(
                        from: root,
                        requestedBucketKey: bucketKeyOrTeamCode.isEmpty ? encodedKey : bucketKeyOrTeamCode,
                        knownBucketHint: knownBucketHint,
                        isPeriodFiltered: isPeriodFiltered
                    )
                    return .success(snapshot, statusCode: resp.statusCode)
                }
                if let hint = knownBucketHint {
                    return .success(
                        TeamReportSnapshot(
                            bucketKey: hint.key,
                            bucketDisplay: hint.display,
                            totalRecruited: hint.count,
                            rows: [],
                            nextCursor: nil,
                            activeRecruiterCount: 0,
                            activeProjectCount: 0,
                            activeHiringDays: 0,
                            avgPerActiveDay: nil,
                            peakDailyCount: nil,
                            peakDateIso: nil,
                            workingCount: isPeriodFiltered ? nil : hint.onCount,
                            waitingCount: isPeriodFiltered ? nil : hint.unconfirmedCount,
                            leftCount: isPeriodFiltered ? nil : hint.offCount
                        ),
                        statusCode: resp.statusCode
                    )
                }
            }

            if resp.statusCode == 400 {
                sawInvalidFilter = true
                continue
            }
            break
        }

        // Fallback when a valid team has 0 new recruits in the filtered period (Server returns 400 INVALID_FILTER when from/to is present)
        if isPeriodFiltered && sawInvalidFilter {
            let primaryCode = candidates.first ?? Self.decodeTeamBucketCode(bucketKeyOrTeamCode)
            let encodedPrimary = Self.encodeTeamBucketKey(primaryCode)
            var isVerifiedTeam = catalogMeta.verifiedCodes.contains(primaryCode.lowercased()) || knownBucketHint != nil
            var probeDisplay = knownBucketHint?.display ?? ""

            let probeResp = await httpClient.request(
                method: "GET",
                path: "/api/reporting/team-report",
                queryItems: [
                    URLQueryItem(name: "bucket_key", value: encodedPrimary),
                    URLQueryItem(name: "limit", value: "1")
                ]
            )
            if probeResp.isSuccess, let probeRoot = probeResp.jsonObject {
                let probeData = (probeRoot["data"] as? [String: Any]) ?? probeRoot
                if probeRoot["report"] != nil || probeRoot["bucket"] != nil || probeData["report"] != nil || probeData["bucket"] != nil {
                    isVerifiedTeam = true
                    let bObj = (probeRoot["bucket"] as? [String: Any]) ?? (probeData["bucket"] as? [String: Any]) ?? [:]
                    let bDisp = bObj.optString("display", "displayName", "display_name", "name")
                    if !bDisp.isEmpty {
                        probeDisplay = bDisp
                    }
                }
            }

            if isVerifiedTeam {
                let finalDisplay = !probeDisplay.isEmpty
                    ? probeDisplay
                    : Self.defaultTeamDisplayName(for: bucketKeyOrTeamCode.isEmpty ? primaryCode : bucketKeyOrTeamCode)
                return .success(
                    TeamReportSnapshot(
                        bucketKey: bucketKeyOrTeamCode.isEmpty ? encodedPrimary : bucketKeyOrTeamCode,
                        bucketDisplay: finalDisplay,
                        totalRecruited: 0,
                        rows: [],
                        nextCursor: nil,
                        activeRecruiterCount: 0,
                        activeProjectCount: 0,
                        activeHiringDays: 0,
                        avgPerActiveDay: nil,
                        peakDailyCount: nil,
                        peakDateIso: nil,
                        workingCount: nil,
                        waitingCount: nil,
                        leftCount: nil,
                        byRecruiter: [],
                        byProject: [],
                        byEmployment: [],
                        byProvider: []
                    ),
                    statusCode: 200
                )
            }
        }

        return .failure(
            message: lastResponse?.errorMessage ?? "Không tải được báo cáo nhóm tuyển dụng.",
            httpStatus: lastResponse?.statusCode ?? 0,
            errorCode: lastResponse?.errorCode
        )
    }

    public func fetchTeamDrillDownPage(
        bucketKeyOrTeamCode: String,
        cursor: String,
        fromDate: String? = nil,
        toDate: String? = nil,
        limit: Int = 25,
        canManageTeamCatalog: Bool = false
    ) async -> MiniBiApiResult<(rows: [TeamDrillDownItem], nextCursor: String?)> {
        let cleanCursor = cursor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanCursor.isEmpty else {
            return .success((rows: [], nextCursor: nil), statusCode: 200)
        }
        let cleanFrom = (fromDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTo = (toDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let dynamicMap = await fetchAdminTeamCodeMap(canManageTeamCatalog: canManageTeamCatalog)
        let candidates = Self.candidateTeamCodes(
            rawKey: bucketKeyOrTeamCode,
            dynamicMap: dynamicMap
        )

        var lastResponse: BackendHttpResponse?
        for candidate in candidates {
            let encodedKey = Self.encodeTeamBucketKey(candidate)
            var queryItems: [URLQueryItem] = [
                URLQueryItem(name: "bucket_key", value: encodedKey),
                URLQueryItem(name: "cursor", value: cleanCursor),
                URLQueryItem(name: "limit", value: String(max(1, limit)))
            ]
            if !cleanFrom.isEmpty {
                queryItems.append(URLQueryItem(name: "from", value: cleanFrom))
            }
            if !cleanTo.isEmpty {
                queryItems.append(URLQueryItem(name: "to", value: cleanTo))
            }
            let resp = await httpClient.request(
                method: "GET",
                path: "/api/reporting/team-drill-down",
                queryItems: queryItems
            )
            lastResponse = resp

            if resp.isSuccess, let root = resp.jsonObject {
                let dataObj = (root["data"] as? [String: Any]) ?? root
                let detailObj = (root["detail"] as? [String: Any])
                    ?? (dataObj["detail"] as? [String: Any])
                    ?? dataObj
                let rows = Self.parseTeamDrillDownRows(from: detailObj, fallbackReport: dataObj)
                let paginationObj = (detailObj["pagination"] as? [String: Any])
                    ?? (dataObj["pagination"] as? [String: Any])
                let nextCursor: String? = {
                    if let hasMore = (detailObj.optNullableInt("has_more", "hasMore") != nil ? detailObj.optBool("has_more", "hasMore") : paginationObj?.optBool("has_more", "hasMore")),
                       hasMore == false {
                        return nil
                    }
                    let raw = detailObj.optNullableString("nextCursor", "next_cursor")
                        ?? paginationObj?.optNullableString("nextCursor", "next_cursor")
                        ?? dataObj.optNullableString("nextCursor", "next_cursor")
                    guard let clean = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !clean.isEmpty else {
                        return nil
                    }
                    return clean
                }()
                return .success((rows: rows, nextCursor: nextCursor), statusCode: resp.statusCode)
            }

            if resp.statusCode == 400 {
                continue
            }
            break
        }

        return .failure(
            message: lastResponse?.errorMessage ?? "Không tải được trang tiếp theo của chi tiết nhóm.",
            httpStatus: lastResponse?.statusCode ?? 0,
            errorCode: lastResponse?.errorCode
        )
    }

    public static func classifyWorkerEmploymentStatus(_ worker: WorkerItem) -> String {
        let code = worker.employmentStatusCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if code == "OFF" { return "OFF" }
        if code == "UNCONFIRMED" { return "UNCONFIRMED" }
        let st = worker.trangThai.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if st.contains("nghỉ") || st == "off" { return "OFF" }
        if st.contains("chưa") || st.contains("chờ") || st == "unconfirmed" { return "UNCONFIRMED" }
        return "ON"
    }

    public static func buildTeamReportFromWorkerRows(
        workers: [WorkerItem],
        bucketKey: String,
        bucketDisplay: String,
        isPeriodFiltered: Bool = false
    ) -> TeamReportSnapshot {
        let total = workers.count
        var working = 0
        var waiting = 0
        var left = 0

        var recMap: [String: (display: String, count: Int, on: Int, wait: Int, off: Int)] = [:]
        var projMap: [String: (display: String, count: Int, on: Int, wait: Int, off: Int)] = [:]
        var empMap: [String: (display: String, count: Int, on: Int, wait: Int, off: Int)] = [:]
        var provMap: [String: (display: String, count: Int, on: Int, wait: Int, off: Int)] = [:]
        var drillMap: [String: TeamDrillDownItem] = [:]

        for w in workers {
            let st = classifyWorkerEmploymentStatus(w)
            let isOn = st == "ON" ? 1 : 0
            let isWait = st == "UNCONFIRMED" ? 1 : 0
            let isOff = st == "OFF" ? 1 : 0
            working += isOn
            waiting += isWait
            left += isOff

            let recName = w.nguoiTuyen.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty("Chưa gán người tuyển")
            let recKey = w.recruiterId.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty(recName).lowercased()
            var rCur = recMap[recKey] ?? (recName, 0, 0, 0, 0)
            rCur.count += 1; rCur.on += isOn; rCur.wait += isWait; rCur.off += isOff
            recMap[recKey] = rCur

            let projName = w.duAn.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty("Chưa phân dự án")
            let projKey = w.projectId.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty(projName).lowercased()
            var pCur = projMap[projKey] ?? (projName, 0, 0, 0, 0)
            pCur.count += 1; pCur.on += isOn; pCur.wait += isWait; pCur.off += isOff
            projMap[projKey] = pCur

            let empName = normalizeBucketDisplay(rawDisplay: w.nganhNghe, fallbackKey: "Thời vụ")
            let empKey = empName.lowercased()
            var eCur = empMap[empKey] ?? (empName, 0, 0, 0, 0)
            eCur.count += 1; eCur.on += isOn; eCur.wait += isWait; eCur.off += isOff
            empMap[empKey] = eCur

            let provName = w.providerType.lowercased() == "vendor" ? "Vendor" : "Nội bộ HRP"
            let provKey = provName.lowercased()
            var prCur = provMap[provKey] ?? (provName, 0, 0, 0, 0)
            prCur.count += 1; prCur.on += isOn; prCur.wait += isWait; prCur.off += isOff
            provMap[provKey] = prCur

            let dateIso = WorkReportsContract.normalizeDateIso(w.ngayVaoLam)
            let drillKey = "\(dateIso)|\(projKey)|\(recKey)|\(provKey)|\(empKey)"
            if let existing = drillMap[drillKey] {
                drillMap[drillKey] = TeamDrillDownItem(
                    id: existing.id,
                    businessDate: existing.businessDate,
                    projectDisplay: existing.projectDisplay,
                    recruiterDisplay: existing.recruiterDisplay,
                    providerTypeDisplay: existing.providerTypeDisplay,
                    employmentTypeDisplay: existing.employmentTypeDisplay,
                    recruitedCount: existing.recruitedCount + 1,
                    firstWorkDate: existing.firstWorkDate
                )
            } else {
                drillMap[drillKey] = TeamDrillDownItem(
                    id: drillKey,
                    businessDate: dateIso,
                    projectDisplay: projName,
                    recruiterDisplay: recName,
                    providerTypeDisplay: provName,
                    employmentTypeDisplay: empName,
                    recruitedCount: 1,
                    firstWorkDate: dateIso
                )
            }
        }

        let byRecruiter = buildBiBucketItems(
            from: recMap.map { ($0.key, $0.value.display, $0.value.count, $0.value.on, $0.value.off, $0.value.wait) },
            totalDenominator: total
        )
        let byProject = buildBiBucketItems(
            from: projMap.map { ($0.key, $0.value.display, $0.value.count, $0.value.on, $0.value.off, $0.value.wait) },
            totalDenominator: total
        )
        let byEmployment = buildBiBucketItems(
            from: empMap.map { ($0.key, $0.value.display, $0.value.count, $0.value.on, $0.value.off, $0.value.wait) },
            totalDenominator: total
        )
        let byProvider = buildBiBucketItems(
            from: provMap.map { ($0.key, $0.value.display, $0.value.count, $0.value.on, $0.value.off, $0.value.wait) },
            totalDenominator: total
        )
        let sortedRows = drillMap.values.sorted { lhs, rhs in
            if lhs.businessDate != rhs.businessDate { return lhs.businessDate > rhs.businessDate }
            if lhs.recruitedCount != rhs.recruitedCount { return lhs.recruitedCount > rhs.recruitedCount }
            return lhs.projectDisplay < rhs.projectDisplay
        }
        let hiringSummary = WorkReportsContract.computeHiringDaySummary(fromWorkers: workers)

        return TeamReportSnapshot(
            bucketKey: bucketKey,
            bucketDisplay: bucketDisplay,
            totalRecruited: total,
            rows: sortedRows,
            nextCursor: nil,
            activeRecruiterCount: byRecruiter.filter { $0.count > 0 }.count,
            activeProjectCount: byProject.filter { $0.count > 0 }.count,
            activeHiringDays: hiringSummary.activeHiringDays,
            avgPerActiveDay: hiringSummary.avgPerActiveDay,
            peakDailyCount: hiringSummary.peakDailyCount,
            peakDateIso: hiringSummary.peakDateIso,
            workingCount: working,
            waitingCount: waiting,
            leftCount: left,
            byRecruiter: byRecruiter,
            byProject: byProject,
            byEmployment: byEmployment,
            byProvider: byProvider
        )
    }

    public static func buildGeneralOverviewSnapshotFromWorkers(
        workers: [WorkerItem],
        audienceKind: String,
        scopeDescription: String,
        isPeriodFiltered: Bool,
        periodFromDate: String?,
        periodToDate: String?,
        managedTotal: Int? = nil,
        recruitedTotal: Int? = nil,
        teamTotal: Int? = nil
    ) -> GeneralOverviewSnapshot {
        let total = workers.count
        var working = 0
        var waiting = 0
        var left = 0

        var recMap: [String: (display: String, count: Int, on: Int, wait: Int, off: Int)] = [:]
        var projMap: [String: (display: String, count: Int, on: Int, wait: Int, off: Int)] = [:]
        var empMap: [String: (display: String, count: Int, on: Int, wait: Int, off: Int)] = [:]
        var provMap: [String: (display: String, count: Int, on: Int, wait: Int, off: Int)] = [:]

        for w in workers {
            let st = classifyWorkerEmploymentStatus(w)
            let isOn = st == "ON" ? 1 : 0
            let isWait = st == "UNCONFIRMED" ? 1 : 0
            let isOff = st == "OFF" ? 1 : 0
            working += isOn
            waiting += isWait
            left += isOff

            let recName = w.nguoiTuyen.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty("Chưa gán người tuyển")
            let recKey = w.recruiterId.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty(recName).lowercased()
            var rCur = recMap[recKey] ?? (recName, 0, 0, 0, 0)
            rCur.count += 1; rCur.on += isOn; rCur.wait += isWait; rCur.off += isOff
            recMap[recKey] = rCur

            let projName = w.duAn.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty("Chưa phân dự án")
            let projKey = w.projectId.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty(projName).lowercased()
            var pCur = projMap[projKey] ?? (projName, 0, 0, 0, 0)
            pCur.count += 1; pCur.on += isOn; pCur.wait += isWait; pCur.off += isOff
            projMap[projKey] = pCur

            let empName = normalizeBucketDisplay(rawDisplay: w.nganhNghe, fallbackKey: "Thời vụ")
            let empKey = empName.lowercased()
            var eCur = empMap[empKey] ?? (empName, 0, 0, 0, 0)
            eCur.count += 1; eCur.on += isOn; eCur.wait += isWait; eCur.off += isOff
            empMap[empKey] = eCur

            let provName = w.providerType.lowercased() == "vendor" ? "Vendor" : "Nội bộ HRP"
            let provKey = provName.lowercased()
            var prCur = provMap[provKey] ?? (provName, 0, 0, 0, 0)
            prCur.count += 1; prCur.on += isOn; prCur.wait += isWait; prCur.off += isOff
            provMap[provKey] = prCur
        }

        let byRecruiter = buildBiBucketItems(
            from: recMap.map { ($0.key, $0.value.display, $0.value.count, $0.value.on, $0.value.off, $0.value.wait) },
            totalDenominator: total
        )
        let byProject = buildBiBucketItems(
            from: projMap.map { ($0.key, $0.value.display, $0.value.count, $0.value.on, $0.value.off, $0.value.wait) },
            totalDenominator: total
        )
        let byEmployment = buildBiBucketItems(
            from: empMap.map { ($0.key, $0.value.display, $0.value.count, $0.value.on, $0.value.off, $0.value.wait) },
            totalDenominator: total
        )
        let byProvider = buildBiBucketItems(
            from: provMap.map { ($0.key, $0.value.display, $0.value.count, $0.value.on, $0.value.off, $0.value.wait) },
            totalDenominator: total
        )
        let hiringSummary = WorkReportsContract.computeHiringDaySummary(fromWorkers: workers)
        let workingRatePct: Double? = total > 0 ? (Double(working) * 100.0 / Double(total)) : nil
        let placementRatePct: Double? = total > 0 ? (Double(working + left) * 100.0 / Double(total)) : nil

        return GeneralOverviewSnapshot(
            asOfDate: "",
            scopeDescription: scopeDescription,
            totalProfiles: total,
            workingCount: working,
            waitingCount: waiting,
            leftCount: left,
            audienceKind: audienceKind,
            isPeriodFiltered: isPeriodFiltered,
            workingRatePct: workingRatePct,
            placementRatePct: placementRatePct,
            retention7dPct: nil,
            retention30dPct: nil,
            closingTotalProfiles: nil,
            closingWorkingCount: nil,
            closingWaitingCount: nil,
            closingLeftCount: nil,
            projectCount: byProject.count,
            recruiterCount: byRecruiter.count,
            managedTotal: managedTotal,
            recruitedTotal: recruitedTotal,
            teamTotal: teamTotal,
            activeHiringDays: hiringSummary.activeHiringDays,
            avgPerActiveDay: hiringSummary.avgPerActiveDay,
            peakDailyCount: hiringSummary.peakDailyCount,
            peakDateIso: hiringSummary.peakDateIso,
            leadingProject: byProject.first,
            byRecruiter: byRecruiter,
            byProject: byProject,
            bySecondaryGroup: byEmployment,
            secondaryGroupTitle: "Cơ cấu theo loại hình lao động",
            byProvider: byProvider,
            periodFromDate: isPeriodFiltered ? periodFromDate : nil,
            periodToDate: isPeriodFiltered ? periodToDate : nil,
            periodNewEpisodes: isPeriodFiltered ? total : nil,
            periodOnInflow: isPeriodFiltered ? working : nil,
            periodOffInflow: isPeriodFiltered ? left : nil,
            periodNetOnChange: isPeriodFiltered ? (working - left) : nil
        )
    }

    public func fetchWorkforceDeepDashboard(
        startDate: String? = nil,
        endDate: String? = nil,
        canManageTeamCatalog: Bool = false
    ) async -> MiniBiApiResult<(
        snapshot: GeneralOverviewSnapshot,
        teamOptions: [BiBucketItem],
        legacyOverview: GeneralOverviewData,
        legacyTeamReport: TeamReportData
    )> {
        let cleanStart = (startDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEnd = (endDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let hasDateFilter = !cleanStart.isEmpty || !cleanEnd.isEmpty

        let response = await fetchCoalescedWorkforceDeepResponse(
            startDate: cleanStart,
            endDate: cleanEnd
        )
        guard response.isSuccess, let root = response.jsonObject else {
            return .failure(
                message: response.errorMessage ?? "Không thể tải báo cáo tổng quát.",
                httpStatus: response.statusCode,
                errorCode: response.errorCode
            )
        }

        if let wfObj = root["workforce"] as? [String: Any] {
            let snapshotObj = (wfObj["snapshot"] as? [String: Any]) ?? [:]
            let balanceObj = (wfObj["balance"] as? [String: Any]) ?? [:]
            let balanceApplicable = balanceObj.optBool("applicable", defaultValue: false)
            let newEpObj = (balanceObj["new_episodes_in_period"] as? [String: Any])
                ?? (balanceObj["newEpisodesInPeriod"] as? [String: Any]) ?? [:]
            let byStatusObj = (balanceObj["by_status"] as? [String: Any])
                ?? (balanceObj["byStatus"] as? [String: Any]) ?? [:]
            let onFlowObj = (byStatusObj["on"] as? [String: Any]) ?? [:]
            let offFlowObj = (byStatusObj["off"] as? [String: Any]) ?? [:]
            let waitingFlowObj = (byStatusObj["unconfirmed"] as? [String: Any]) ?? [:]
            let retentionObj = (wfObj["retention"] as? [String: Any]) ?? [:]
            let checkpointsObj = (retentionObj["checkpoints"] as? [String: Any]) ?? [:]
            let d30Obj = (checkpointsObj["d30"] as? [String: Any]) ?? [:]
            let d7Obj = (checkpointsObj["d7"] as? [String: Any]) ?? [:]
            let periodCohortObj = (retentionObj["period_cohort"] as? [String: Any])
                ?? (retentionObj["periodCohort"] as? [String: Any]) ?? [:]
            let periodCpObj = (periodCohortObj["checkpoints"] as? [String: Any]) ?? [:]
            let periodD7Obj = (periodCpObj["d7"] as? [String: Any]) ?? [:]

            let snapshotTotal = snapshotObj.optInt("eligible_episode_total", "eligibleEpisodeTotal", "total")
            let snapshotOn = snapshotObj.optInt("on_count", "onCount", "active_count")
            let snapshotOff = snapshotObj.optInt("off_count", "offCount", "inactive_count")
            let snapshotUnconfirmed = snapshotObj.optInt("unconfirmed_count", "unconfirmedCount", "interview_count")
            let asOfDate = wfObj.optString(
                "as_of_date",
                "asOfDate",
                defaultValue: snapshotObj.optString("as_of_date", "asOfDate", defaultValue: root.optString("as_of_date", "asOfDate"))
            )

            let d7RatePct: Double? = {
                if let r = d7Obj.optNullableDouble("retention_rate", "retentionRate") {
                    return r <= 1.0 && r > 0.0 ? r * 100.0 : r
                }
                return nil
            }()
            let d30RatePct: Double? = {
                if let r = d30Obj.optNullableDouble("retention_rate", "retentionRate") {
                    return r <= 1.0 && r > 0.0 ? r * 100.0 : r
                }
                return nil
            }()
            let periodD7RatePct: Double? = {
                if let r = periodD7Obj.optNullableDouble("retention_rate", "retentionRate") {
                    return r <= 1.0 && r > 0.0 ? r * 100.0 : r
                }
                return nil
            }()

            let dimsObj = (wfObj["dimensions"] as? [String: Any]) ?? [:]
            let byTeamObj = (dimsObj["by_team"] as? [String: Any])
                ?? (dimsObj["byTeam"] as? [String: Any]) ?? [:]
            let teamBucketsRaw = byTeamObj.optObjectArray("buckets")

            let byProjectObj = (dimsObj["by_project"] as? [String: Any])
                ?? (dimsObj["byProject"] as? [String: Any]) ?? [:]
            let projectsBucketsRaw = byProjectObj.optObjectArray("buckets")
            let projectPaginationObj = (byProjectObj["pagination"] as? [String: Any]) ?? [:]
            let totalProjectCountDim = max(
                projectPaginationObj.optInt("total_count", "totalCount"),
                projectsBucketsRaw.count
            )

            let byRecruiterObj = (dimsObj["by_recruiter"] as? [String: Any])
                ?? (dimsObj["byRecruiter"] as? [String: Any]) ?? [:]
            let recruitersBucketsRaw = byRecruiterObj.optObjectArray("buckets")
            let recruiterPaginationObj = (byRecruiterObj["pagination"] as? [String: Any]) ?? [:]
            let totalRecruiterCountDim = max(
                recruiterPaginationObj.optInt("total_count", "totalCount"),
                recruitersBucketsRaw.count
            )

            let byProviderObj = (dimsObj["by_provider"] as? [String: Any])
                ?? (dimsObj["byProvider"] as? [String: Any]) ?? [:]
            let providerBucketsRaw = byProviderObj.optObjectArray("buckets")

            func parseDimBuckets(_ arr: [[String: Any]], fallbackPrefix: String, denom: Int) -> [BiBucketItem] {
                let entries = arr.enumerated().compactMap { idx, obj -> (key: String, display: String, totalCount: Int, onCount: Int?, offCount: Int?, unconfirmedCount: Int?)? in
                    let count = obj.optInt("eligible_episode_count", "eligibleEpisodeCount", "recruitedCount", "recruited_count", "total_workers", "total", "count")
                    let key = obj.optString("key", "id", "code", "project_id", "recruiter_id", "team_id", defaultValue: "\(fallbackPrefix)_\(idx)")
                    let display = Self.normalizeBucketDisplay(
                        rawDisplay: obj.optString("display", "displayName", "display_name", "project_display", "recruiter_display", "team_display", "label", "name", defaultValue: key),
                        fallbackKey: key
                    )
                    let onCnt = obj.optNullableInt("on_count", "onCount", "active_count")
                    let offCnt = obj.optNullableInt("off_count", "offCount", "inactive_count")
                    let unconfCnt = obj.optNullableInt("unconfirmed_count", "unconfirmedCount")
                    return (key, display, count, onCnt, offCnt, unconfCnt)
                }
                return Self.buildBiBucketItems(from: entries, totalDenominator: denom)
            }

            let normalizedTeams = parseDimBuckets(teamBucketsRaw, fallbackPrefix: "team", denom: snapshotTotal)
            let byProjectDim = parseDimBuckets(projectsBucketsRaw, fallbackPrefix: "proj", denom: snapshotTotal)
            let byRecruiterDim = parseDimBuckets(recruitersBucketsRaw, fallbackPrefix: "rec", denom: snapshotTotal)
            let byProviderDim = parseDimBuckets(providerBucketsRaw, fallbackPrefix: "prov", denom: snapshotTotal)

            let periodAgg: PeriodAllScopeAggregation? = hasDateFilter
                ? await fetchCoalescedPeriodAggregation(
                    teamBucketsRaw: teamBucketsRaw,
                    startDate: cleanStart,
                    endDate: cleanEnd,
                    canManageTeamCatalog: canManageTeamCatalog
                )
                : nil

            let newCount = newEpObj.optInt("total", "count")
            let onInflow = onFlowObj.optInt("total_inflow_count", "totalInflowCount", "count")
            let offInflow = offFlowObj.optInt("total_inflow_count", "totalInflowCount", "count")
            let waitingInflow = waitingFlowObj.optInt("total_inflow_count", "totalInflowCount", "count")
            let netOnChange = onFlowObj.optNullableInt("net_change", "netChange") ?? (onInflow - offInflow)

            let snapshot: GeneralOverviewSnapshot
            let teamOptions: [BiBucketItem]

            if hasDateFilter {
                let totalProfiles: Int = {
                    if let agg = periodAgg, agg.totalWorkers > 0 {
                        return agg.totalWorkers
                    }
                    if balanceApplicable {
                        return newCount
                    }
                    return snapshotTotal
                }()
                let workingCount = balanceApplicable ? onInflow : (periodAgg?.activeCount ?? snapshotOn)
                let waitingCount = balanceApplicable ? waitingInflow : (periodAgg?.unconfirmedCount ?? snapshotUnconfirmed)
                let leftCount = balanceApplicable ? offInflow : (periodAgg?.inactiveCount ?? snapshotOff)

                let finalByRecruiter = (periodAgg?.byRecruiterItems.isEmpty == false) ? periodAgg!.byRecruiterItems : byRecruiterDim
                let finalByProject = (periodAgg?.byProjectItems.isEmpty == false) ? periodAgg!.byProjectItems : byProjectDim
                let finalByTeam = (periodAgg?.byTeamItems.isEmpty == false) ? periodAgg!.byTeamItems : normalizedTeams
                let finalByProvider = (periodAgg?.byProviderItems.isEmpty == false) ? periodAgg!.byProviderItems : byProviderDim

                if let agg = periodAgg, !agg.byTeamItems.isEmpty {
                    var periodMap: [String: BiBucketItem] = [:]
                    for item in agg.byTeamItems {
                        periodMap[item.key.lowercased()] = item
                    }
                    var mergedOptions: [BiBucketItem] = []
                    var seenKeys: Set<String> = []
                    for baseTeam in normalizedTeams {
                        let lk = baseTeam.key.lowercased()
                        seenKeys.insert(lk)
                        if let matched = periodMap[lk] {
                            mergedOptions.append(matched)
                        } else {
                            mergedOptions.append(
                                BiBucketItem(
                                    key: baseTeam.key,
                                    display: baseTeam.display,
                                    count: 0,
                                    sharePct: 0.0,
                                    onCount: nil,
                                    unconfirmedCount: nil,
                                    offCount: nil
                                )
                            )
                        }
                    }
                    for item in agg.byTeamItems where !seenKeys.contains(item.key.lowercased()) {
                        mergedOptions.append(item)
                    }
                    teamOptions = mergedOptions
                } else {
                    teamOptions = normalizedTeams
                }

                snapshot = GeneralOverviewSnapshot(
                    asOfDate: asOfDate,
                    scopeDescription: "Toàn hệ thống",
                    totalProfiles: totalProfiles,
                    workingCount: workingCount,
                    waitingCount: waitingCount,
                    leftCount: leftCount,
                    audienceKind: "all",
                    isPeriodFiltered: true,
                    workingRatePct: snapshotTotal > 0 ? (Double(snapshotOn) * 100.0 / Double(snapshotTotal)) : nil,
                    placementRatePct: snapshotTotal > 0 ? (Double(snapshotOn + snapshotOff) * 100.0 / Double(snapshotTotal)) : nil,
                    retention7dPct: periodD7RatePct ?? d7RatePct,
                    retention30dPct: d30RatePct,
                    closingTotalProfiles: snapshotTotal,
                    closingWorkingCount: snapshotOn,
                    closingWaitingCount: snapshotUnconfirmed,
                    closingLeftCount: snapshotOff,
                    projectCount: finalByProject.count,
                    recruiterCount: finalByRecruiter.count,
                    managedTotal: nil,
                    recruitedTotal: nil,
                    teamTotal: nil,
                    activeHiringDays: periodAgg?.hiringSummary.activeHiringDays ?? 0,
                    avgPerActiveDay: periodAgg?.hiringSummary.avgPerActiveDay,
                    peakDailyCount: periodAgg?.hiringSummary.peakDailyCount,
                    peakDateIso: periodAgg?.hiringSummary.peakDateIso,
                    leadingProject: finalByProject.first,
                    byRecruiter: finalByRecruiter,
                    byProject: finalByProject,
                    bySecondaryGroup: finalByTeam,
                    secondaryGroupTitle: "Cơ cấu theo nhóm tuyển dụng",
                    byProvider: finalByProvider,
                    periodFromDate: cleanStart,
                    periodToDate: cleanEnd,
                    periodNewEpisodes: totalProfiles,
                    periodOnInflow: workingCount,
                    periodOffInflow: leftCount,
                    periodNetOnChange: netOnChange
                )
            } else {
                teamOptions = normalizedTeams
                snapshot = GeneralOverviewSnapshot(
                    asOfDate: asOfDate,
                    scopeDescription: "Toàn hệ thống",
                    totalProfiles: snapshotTotal,
                    workingCount: snapshotOn,
                    waitingCount: snapshotUnconfirmed,
                    leftCount: snapshotOff,
                    audienceKind: "all",
                    isPeriodFiltered: false,
                    workingRatePct: snapshotTotal > 0 ? (Double(snapshotOn) * 100.0 / Double(snapshotTotal)) : nil,
                    placementRatePct: snapshotTotal > 0 ? (Double(snapshotOn + snapshotOff) * 100.0 / Double(snapshotTotal)) : nil,
                    retention7dPct: d7RatePct,
                    retention30dPct: d30RatePct,
                    closingTotalProfiles: snapshotTotal,
                    closingWorkingCount: snapshotOn,
                    closingWaitingCount: snapshotUnconfirmed,
                    closingLeftCount: snapshotOff,
                    projectCount: max(totalProjectCountDim, byProjectDim.count),
                    recruiterCount: max(totalRecruiterCountDim, byRecruiterDim.count),
                    managedTotal: nil,
                    recruitedTotal: nil,
                    teamTotal: nil,
                    activeHiringDays: 0,
                    avgPerActiveDay: nil,
                    peakDailyCount: nil,
                    peakDateIso: nil,
                    leadingProject: byProjectDim.first,
                    byRecruiter: byRecruiterDim,
                    byProject: byProjectDim,
                    bySecondaryGroup: normalizedTeams,
                    secondaryGroupTitle: "Cơ cấu theo nhóm tuyển dụng",
                    byProvider: byProviderDim,
                    periodFromDate: nil,
                    periodToDate: nil,
                    periodNewEpisodes: nil,
                    periodOnInflow: nil,
                    periodOffInflow: nil,
                    periodNetOnChange: nil
                )
            }

            let legacyProjects = snapshot.byProject.enumerated().map { idx, b in
                ProjectBreakdownRow(
                    id: b.key.isEmpty ? "proj_\(idx)" : b.key,
                    projectName: b.display,
                    totalCount: b.count,
                    activeCount: b.onCount ?? 0,
                    inactiveCount: b.offCount ?? 0,
                    newCount: b.unconfirmedCount ?? 0,
                    activeSharePct: b.sharePct
                )
            }
            let legacyRecruiters = snapshot.byRecruiter.map { b in
                PersonPerformanceRow(
                    id: b.key,
                    code: b.key,
                    name: b.display,
                    totalCount: b.count,
                    activeCount: b.onCount ?? 0,
                    inactiveCount: b.offCount ?? 0,
                    activeRatePct: b.sharePct
                )
            }
            let legacyManagers = snapshot.bySecondaryGroup.map { b in
                PersonPerformanceRow(
                    id: b.key,
                    code: b.key,
                    name: b.display,
                    totalCount: b.count,
                    activeCount: b.onCount ?? 0,
                    inactiveCount: b.offCount ?? 0,
                    activeRatePct: b.sharePct
                )
            }
            let legacyOverview = GeneralOverviewData(
                scope: "all",
                kpis: GeneralOverviewKpis(
                    totalHeadcount: snapshot.totalProfiles,
                    activeCount: snapshot.workingCount,
                    inactiveCount: snapshot.leftCount,
                    interviewCount: snapshot.waitingCount,
                    newCount: newCount,
                    resignedInPeriodCount: offInflow,
                    retentionRate: snapshot.retention30dPct ?? snapshot.workingRatePct ?? 0.0,
                    turnoverRate: snapshot.totalProfiles > 0 ? (Double(snapshot.leftCount) * 100.0 / Double(snapshot.totalProfiles)) : 0.0
                ),
                projects: legacyProjects,
                projectsTotal: snapshot.projectCount,
                projectsPage: 1,
                projectsTotalPages: 1,
                recruiters: legacyRecruiters,
                managers: legacyManagers
            )
            let legacyTeams: [TeamSummaryRow] = teamOptions.map { b in
                TeamSummaryRow(
                    id: b.key,
                    teamCode: b.key,
                    teamName: b.display,
                    leaderName: "",
                    memberCount: 0,
                    totalWorkers: b.count,
                    activeWorkers: b.onCount ?? 0,
                    inactiveWorkers: b.offCount ?? 0,
                    newWorkers: b.unconfirmedCount ?? 0,
                    activeRatePct: b.sharePct,
                    members: []
                )
            }

            return .success(
                (
                    snapshot: snapshot,
                    teamOptions: teamOptions,
                    legacyOverview: legacyOverview,
                    legacyTeamReport: TeamReportData(teams: legacyTeams)
                ),
                statusCode: response.statusCode
            )
        }

        // Legacy fallback JSON format (`root["report"]` / `root["kpis"]`)
        let reportObj = (root["report"] as? [String: Any])
            ?? (root["data"] as? [String: Any])
            ?? root
        let kpisObj = (reportObj["kpis"] as? [String: Any])
            ?? (reportObj["summary"] as? [String: Any])
            ?? reportObj
        let totalWorkers = kpisObj.optInt("total_workers", "total_headcount", "total")
        let activeCount = kpisObj.optInt("on_count", "active_count", "working_count", "active")
        let inactiveCount = kpisObj.optInt("off_count", "inactive_count", "resigned_count", "inactive")
        let unconfirmedCount = kpisObj.optInt("unconfirmed_count", "interview_count", "interview")
        let projEntries = Self.parseReportingBucketEntries(from: reportObj, keys: ["by_project", "projects"])
        let recEntries = Self.parseReportingBucketEntries(from: reportObj, keys: ["by_recruiter", "recruiters"])
        let byProject = Self.buildBiBucketItems(from: projEntries, totalDenominator: totalWorkers)
        let byRecruiter = Self.buildBiBucketItems(from: recEntries, totalDenominator: totalWorkers)

        let snapshot = GeneralOverviewSnapshot(
            asOfDate: "",
            scopeDescription: "Toàn hệ thống",
            totalProfiles: totalWorkers,
            workingCount: activeCount,
            waitingCount: unconfirmedCount,
            leftCount: inactiveCount,
            audienceKind: "all",
            isPeriodFiltered: hasDateFilter,
            workingRatePct: totalWorkers > 0 ? (Double(activeCount) * 100.0 / Double(totalWorkers)) : nil,
            placementRatePct: totalWorkers > 0 ? (Double(activeCount + inactiveCount) * 100.0 / Double(totalWorkers)) : nil,
            projectCount: byProject.count,
            recruiterCount: byRecruiter.count,
            leadingProject: byProject.first,
            byRecruiter: byRecruiter,
            byProject: byProject,
            bySecondaryGroup: [],
            secondaryGroupTitle: "Cơ cấu theo nhóm tuyển dụng",
            byProvider: [],
            periodFromDate: hasDateFilter ? cleanStart : nil,
            periodToDate: hasDateFilter ? cleanEnd : nil
        )
        let legacyOverview = GeneralOverviewData(
            scope: "all",
            kpis: GeneralOverviewKpis(
                totalHeadcount: totalWorkers,
                activeCount: activeCount,
                inactiveCount: inactiveCount,
                interviewCount: unconfirmedCount
            )
        )
        return .success(
            (
                snapshot: snapshot,
                teamOptions: [],
                legacyOverview: legacyOverview,
                legacyTeamReport: TeamReportData(teams: [])
            ),
            statusCode: response.statusCode
        )
    }

    public func fetchScopedDashboardSnapshots(
        user: MiniBiUser,
        startDate: String? = nil,
        endDate: String? = nil
    ) async -> MiniBiApiResult<(
        snapshot: GeneralOverviewSnapshot,
        teamOptions: [BiBucketItem],
        teamReportsByKey: [String: TeamReportSnapshot],
        canViewTeamReport: Bool,
        legacyOverview: GeneralOverviewData,
        legacyTeamReport: TeamReportData
    )> {
        let allowedSet = Set(user.safeAllowedWorkerDirectoryScopes)
        let hasTeamScope = user.hasScopeKind("team")
        let scopesToLoad = ["team", "managed", "recruited"].filter { allowedSet.contains($0) }
        let cleanStart = (startDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEnd = (endDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let isPeriodFiltered = !cleanStart.isEmpty || !cleanEnd.isEmpty

        let repo = MiniBiRepository(httpClient: httpClient, keychain: KeychainStore.shared)
        var rowsByScope: [String: [WorkerItem]] = [:]
        var anyStatusCode: Int?
        var firstError: (message: String, status: Int, code: String?)?

        for sc in scopesToLoad {
            var seenInScope: Set<String> = []
            var scopeItems: [WorkerItem] = []
            var cursor: String? = nil
            for page in 1...10 {
                let res = await repo.fetchWorkers(
                    scope: sc,
                    cursor: cursor,
                    page: page,
                    pageSize: 100
                )
                switch res {
                case .success(let wData, let status):
                    anyStatusCode = status
                    var addedInPage = 0
                    for item in wData.items {
                        let key = item.maNld.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        guard !key.isEmpty, seenInScope.insert(key).inserted else { continue }
                        scopeItems.append(item)
                        addedInPage += 1
                    }
                    let nextCur = (wData.nextCursor ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let hasMorePages = wData.hasMore || (page < wData.totalPages)
                    if !hasMorePages || addedInPage == 0 {
                        break
                    }
                    cursor = nextCur.isEmpty ? nil : nextCur
                case .failure(let message, let httpStatus, let errorCode, _):
                    if firstError == nil {
                        firstError = (message, httpStatus, errorCode)
                    }
                    break
                }
                if firstError != nil && scopeItems.isEmpty {
                    break
                }
            }
            if isPeriodFiltered {
                scopeItems = scopeItems.filter { item in
                    let dateIso = WorkReportsContract.normalizeDateIso(item.ngayVaoLam)
                    guard !dateIso.isEmpty else { return false }
                    if !cleanStart.isEmpty && dateIso < cleanStart { return false }
                    if !cleanEnd.isEmpty && dateIso > cleanEnd { return false }
                    return true
                }
            }
            rowsByScope[sc] = scopeItems
        }

        if anyStatusCode == nil, let err = firstError {
            return .failure(message: err.message, httpStatus: err.status, errorCode: err.code)
        }

        var combinedSeen: Set<String> = []
        var combinedWorkers: [WorkerItem] = []
        for sc in scopesToLoad {
            for item in rowsByScope[sc] ?? [] {
                let key = item.maNld.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !key.isEmpty, combinedSeen.insert(key).inserted else { continue }
                combinedWorkers.append(item)
            }
        }

        let teamTotal: Int? = allowedSet.contains("team") ? (rowsByScope["team"]?.count ?? 0) : nil
        let managedTotal: Int? = allowedSet.contains("managed") ? (rowsByScope["managed"]?.count ?? 0) : nil
        let recruitedTotal: Int? = allowedSet.contains("recruited") ? (rowsByScope["recruited"]?.count ?? 0) : nil
        let audienceKind = hasTeamScope ? "team" : "own"
        let scopeDesc: String = {
            let base = hasTeamScope ? "Phạm vi nhóm phụ trách" : "Phạm vi cá nhân (dự án quản lý & tự tuyển)"
            if isPeriodFiltered {
                return "\(base) · Kỳ \(cleanStart) → \(cleanEnd)"
            }
            return base
        }()

        let snapshot = Self.buildGeneralOverviewSnapshotFromWorkers(
            workers: combinedWorkers,
            audienceKind: audienceKind,
            scopeDescription: scopeDesc,
            isPeriodFiltered: isPeriodFiltered,
            periodFromDate: isPeriodFiltered ? cleanStart : nil,
            periodToDate: isPeriodFiltered ? cleanEnd : nil,
            managedTotal: managedTotal,
            recruitedTotal: recruitedTotal,
            teamTotal: teamTotal
        )

        var teamOptions: [BiBucketItem] = []
        var teamReportsByKey: [String: TeamReportSnapshot] = [:]
        var legacyTeams: [TeamSummaryRow] = []

        if hasTeamScope {
            let teamSourceWorkers = rowsByScope["team"] ?? combinedWorkers
            var groupedByTeam: [String: (display: String, rows: [WorkerItem])] = [:]
            let fallbackTeamRef = user.scopeReferences(forKind: "team").first ?? "team_scope"

            for w in teamSourceWorkers {
                let rawKey = w.teamId.trimmingCharacters(in: .whitespacesAndNewlines)
                    .ifEmpty(w.nhom.trimmingCharacters(in: .whitespacesAndNewlines))
                    .ifEmpty(fallbackTeamRef)
                let rawDisplay = w.nhom.trimmingCharacters(in: .whitespacesAndNewlines)
                    .ifEmpty(w.teamId.trimmingCharacters(in: .whitespacesAndNewlines))
                    .ifEmpty("Nhóm phụ trách")
                var cur = groupedByTeam[rawKey] ?? (rawDisplay, [])
                cur.rows.append(w)
                groupedByTeam[rawKey] = cur
            }

            if groupedByTeam.isEmpty {
                groupedByTeam[fallbackTeamRef] = ("Nhóm phụ trách", [])
            }

            let totalTeamWorkers = max(1, teamSourceWorkers.count)
            let sortedTeamEntries = groupedByTeam.sorted { lhs, rhs in
                if lhs.value.rows.count != rhs.value.rows.count {
                    return lhs.value.rows.count > rhs.value.rows.count
                }
                return lhs.value.display < rhs.value.display
            }

            for entry in sortedTeamEntries {
                let bKey = entry.key
                let bDisplay = entry.value.display
                let bRows = entry.value.rows
                let reportSnap = Self.buildTeamReportFromWorkerRows(
                    workers: bRows,
                    bucketKey: bKey,
                    bucketDisplay: bDisplay,
                    isPeriodFiltered: isPeriodFiltered
                )
                teamReportsByKey[bKey] = reportSnap
                let share = teamSourceWorkers.isEmpty ? 0.0 : (Double(bRows.count) * 100.0 / Double(totalTeamWorkers))
                teamOptions.append(
                    BiBucketItem(
                        key: bKey,
                        display: bDisplay,
                        count: bRows.count,
                        sharePct: share,
                        onCount: reportSnap.workingCount,
                        unconfirmedCount: reportSnap.waitingCount,
                        offCount: reportSnap.leftCount
                    )
                )
                legacyTeams.append(
                    TeamSummaryRow(
                        id: bKey,
                        teamCode: bKey,
                        teamName: bDisplay,
                        leaderName: "",
                        memberCount: reportSnap.activeRecruiterCount,
                        totalWorkers: bRows.count,
                        activeWorkers: reportSnap.workingCount ?? 0,
                        inactiveWorkers: reportSnap.leftCount ?? 0,
                        newWorkers: isPeriodFiltered ? bRows.count : 0,
                        activeRatePct: bRows.isEmpty ? 0.0 : (Double(reportSnap.workingCount ?? 0) * 100.0 / Double(bRows.count)),
                        members: []
                    )
                )
            }
        }

        let legacyOverview = GeneralOverviewData(
            scope: audienceKind,
            kpis: GeneralOverviewKpis(
                totalHeadcount: snapshot.totalProfiles,
                activeCount: snapshot.workingCount,
                inactiveCount: snapshot.leftCount,
                interviewCount: snapshot.waitingCount,
                newCount: isPeriodFiltered ? snapshot.totalProfiles : 0,
                resignedInPeriodCount: isPeriodFiltered ? snapshot.leftCount : 0,
                retentionRate: snapshot.workingRatePct ?? 0.0,
                turnoverRate: snapshot.totalProfiles > 0 ? (Double(snapshot.leftCount) * 100.0 / Double(snapshot.totalProfiles)) : 0.0
            )
        )

        return .success(
            (
                snapshot: snapshot,
                teamOptions: teamOptions,
                teamReportsByKey: teamReportsByKey,
                canViewTeamReport: hasTeamScope,
                legacyOverview: legacyOverview,
                legacyTeamReport: TeamReportData(teams: legacyTeams)
            ),
            statusCode: anyStatusCode ?? 200
        )
    }

    private static func normalizeWorkerDateIso(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let prefix10 = String(trimmed.prefix(10))
        let parts = prefix10.split(separator: "/")
        if parts.count == 3, parts[0].count == 2, parts[1].count == 2, parts[2].count == 4 {
            return "\(parts[2])-\(parts[1])-\(parts[0])"
        }
        return prefix10
    }

    private func fetchMergedWorkersForScopedFallback(
        preferredScope: String,
        allowedWorkerScopes: [String] = [],
        startDate: String? = nil,
        endDate: String? = nil
    ) async -> (items: [WorkerItem], total: Int, statusCode: Int)? {
        let allowedSet = Set(MiniBiUser.sanitizeAllowedWorkerTabs(allowedWorkerScopes))
        guard !allowedSet.isEmpty else { return nil }

        let norm = preferredScope.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let scopesToTry: [String] = {
            switch norm {
            case "own", "personal":
                return ["managed", "recruited"].filter { allowedSet.contains($0) }
            case "team":
                return allowedSet.contains("team") ? ["team"] : []
            case "managed", "recruited", "all":
                return allowedSet.contains(norm) ? [norm] : []
            default:
                return []
            }
        }()
        guard !scopesToTry.isEmpty else { return nil }

        let cleanStart = (startDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEnd = (endDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let hasDateFilter = !cleanStart.isEmpty || !cleanEnd.isEmpty

        var seenIds: Set<String> = []
        var merged: [WorkerItem] = []
        var reportedTotal = 0
        var anySuccessStatus: Int?

        let repo = MiniBiRepository(httpClient: httpClient, keychain: KeychainStore.shared)
        for sc in scopesToTry {
            let res = await repo.fetchWorkers(scope: sc, pageSize: 100)
            if case .success(let wData, let status) = res {
                anySuccessStatus = status
                reportedTotal = max(reportedTotal, wData.total)
                for item in wData.items where !seenIds.contains(item.maNld) {
                    seenIds.insert(item.maNld)
                    merged.append(item)
                }
            }
        }

        guard let statusCode = anySuccessStatus else { return nil }

        if hasDateFilter {
            let filtered = merged.filter { item in
                let dateIso = Self.normalizeWorkerDateIso(item.ngayVaoLam)
                guard !dateIso.isEmpty else { return false }
                if !cleanStart.isEmpty && dateIso < cleanStart { return false }
                if !cleanEnd.isEmpty && dateIso > cleanEnd { return false }
                return true
            }
            return (filtered, filtered.count, statusCode)
        }

        return (merged, max(reportedTotal, merged.count), statusCode)
    }

    public func fetchGeneralOverview(
        scope: String = "all",
        allowedWorkerScopes: [String] = [],
        startDate: String? = nil,
        endDate: String? = nil,
        projectFilter: String = "ACTIVE",
        projectSearch: String = "",
        projectsPage: Int = 1,
        projectsPageSize: Int = 20
    ) async -> MiniBiApiResult<GeneralOverviewData> {
        let normalizedScope = scope.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanStart = (startDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEnd = (endDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let hasDateFilter = !cleanStart.isEmpty || !cleanEnd.isEmpty

        if normalizedScope == "all" || normalizedScope.isEmpty {
            let response = await fetchCoalescedWorkforceDeepResponse(
                startDate: cleanStart,
                endDate: cleanEnd
            )

            if response.isSuccess, let root = response.jsonObject {
                if let wfObj = root["workforce"] as? [String: Any] {
                    let snapshotObj = (wfObj["snapshot"] as? [String: Any]) ?? [:]
                    let balanceObj = (wfObj["balance"] as? [String: Any]) ?? [:]
                    let balanceApplicable = balanceObj.optBool("applicable", defaultValue: false)
                    let newEpObj = (balanceObj["new_episodes_in_period"] as? [String: Any])
                        ?? (balanceObj["newEpisodesInPeriod"] as? [String: Any]) ?? [:]
                    let byStatusObj = (balanceObj["by_status"] as? [String: Any])
                        ?? (balanceObj["byStatus"] as? [String: Any]) ?? [:]
                    let onFlowObj = (byStatusObj["on"] as? [String: Any]) ?? [:]
                    let offFlowObj = (byStatusObj["off"] as? [String: Any]) ?? [:]
                    let waitingFlowObj = (byStatusObj["unconfirmed"] as? [String: Any]) ?? [:]
                    let retentionObj = (wfObj["retention"] as? [String: Any]) ?? [:]
                    let checkpointsObj = (retentionObj["checkpoints"] as? [String: Any]) ?? [:]
                    let d30Obj = (checkpointsObj["d30"] as? [String: Any]) ?? [:]
                    let d7Obj = (checkpointsObj["d7"] as? [String: Any]) ?? [:]
                    let periodCohortObj = (retentionObj["period_cohort"] as? [String: Any])
                        ?? (retentionObj["periodCohort"] as? [String: Any]) ?? [:]
                    let periodCpObj = (periodCohortObj["checkpoints"] as? [String: Any]) ?? [:]
                    let periodD7Obj = (periodCpObj["d7"] as? [String: Any]) ?? [:]

                    let snapshotTotal = snapshotObj.optInt("eligible_episode_total", "eligibleEpisodeTotal", "total")
                    let snapshotOn = snapshotObj.optInt("on_count", "onCount", "active_count")
                    let snapshotOff = snapshotObj.optInt("off_count", "offCount", "inactive_count")
                    let snapshotUnconfirmed = snapshotObj.optInt("unconfirmed_count", "unconfirmedCount", "interview_count")
                    let newCount = newEpObj.optInt("total", "count")
                    let resignedInPeriodCount = offFlowObj.optInt("total_inflow_count", "totalInflowCount", "count")

                    let dimsObj = (wfObj["dimensions"] as? [String: Any]) ?? [:]
                    let byTeamObj = (dimsObj["by_team"] as? [String: Any])
                        ?? (dimsObj["byTeam"] as? [String: Any]) ?? [:]
                    let teamBuckets = byTeamObj.optObjectArray("buckets")

                    let periodAgg: PeriodAllScopeAggregation? = hasDateFilter
                        ? await fetchCoalescedPeriodAggregation(
                            teamBucketsRaw: teamBuckets,
                            startDate: cleanStart,
                            endDate: cleanEnd
                        )
                        : nil

                    let totalWorkers: Int
                    let activeCount: Int
                    let inactiveCount: Int
                    let unconfirmedCount: Int
                    if hasDateFilter && balanceApplicable {
                        totalWorkers = newCount
                        activeCount = onFlowObj.optInt("total_inflow_count", "totalInflowCount", "count")
                        inactiveCount = resignedInPeriodCount
                        unconfirmedCount = waitingFlowObj.optInt("total_inflow_count", "totalInflowCount", "count")
                    } else if let periodAgg, hasDateFilter {
                        totalWorkers = periodAgg.totalWorkers
                        activeCount = periodAgg.activeCount
                        inactiveCount = periodAgg.inactiveCount
                        unconfirmedCount = periodAgg.unconfirmedCount
                    } else {
                        totalWorkers = snapshotTotal
                        activeCount = snapshotOn
                        inactiveCount = snapshotOff
                        unconfirmedCount = snapshotUnconfirmed
                    }

                    let retentionRate: Double = {
                        if hasDateFilter {
                            if let pRate = periodD7Obj.optNullableDouble("retention_rate", "retentionRate") {
                                return pRate <= 1.0 && pRate > 0.0 ? pRate * 100.0 : pRate
                            }
                            if let d7Rate = d7Obj.optNullableDouble("retention_rate", "retentionRate") {
                                return d7Rate <= 1.0 && d7Rate > 0.0 ? d7Rate * 100.0 : d7Rate
                            }
                        }
                        if let r = d30Obj.optNullableDouble("retention_rate", "retentionRate") {
                            return r <= 1.0 && r > 0.0 ? r * 100.0 : r
                        }
                        return snapshotTotal > 0 ? (Double(snapshotOn) * 100.0 / Double(snapshotTotal)) : 0.0
                    }()
                    let turnoverRate: Double = {
                        if hasDateFilter && totalWorkers > 0 {
                            return Double(inactiveCount) * 100.0 / Double(totalWorkers)
                        }
                        return snapshotTotal > 0
                            ? (Double(snapshotOff) * 100.0 / Double(snapshotTotal))
                            : 0.0
                    }()

                    let kpis = GeneralOverviewKpis(
                        totalHeadcount: totalWorkers,
                        activeCount: activeCount,
                        inactiveCount: inactiveCount,
                        interviewCount: unconfirmedCount,
                        newCount: newCount,
                        resignedInPeriodCount: resignedInPeriodCount,
                        retentionRate: retentionRate,
                        turnoverRate: turnoverRate
                    )

                    if let periodAgg, hasDateFilter {
                        return .success(
                            GeneralOverviewData(
                                scope: scope,
                                kpis: kpis,
                                projects: periodAgg.projects,
                                projectsTotal: periodAgg.projects.count,
                                projectsPage: 1,
                                projectsTotalPages: 1,
                                recruiters: periodAgg.recruiters,
                                managers: periodAgg.managers
                            ),
                            statusCode: response.statusCode
                        )
                    }

                    let byProjectObj = (dimsObj["by_project"] as? [String: Any])
                        ?? (dimsObj["byProject"] as? [String: Any]) ?? [:]
                    let projectsBuckets = byProjectObj.optObjectArray("buckets")
                    let projectPaginationObj = (byProjectObj["pagination"] as? [String: Any]) ?? [:]
                    let totalProjectCount = max(
                        projectPaginationObj.optInt("total_count", "totalCount"),
                        projectsBuckets.count
                    )

                    let projects: [ProjectBreakdownRow] = projectsBuckets.enumerated().map { idx, p in
                        let name = p.optString("display", "project_display", "du_an", "project_name", "name", "key", defaultValue: "Dự án #\(idx + 1)")
                        let pTotal = p.optInt("eligible_episode_count", "eligibleEpisodeCount", "total_workers", "total")
                        let pActive = p.optInt("on_count", "onCount", "active_count")
                        let pInactive = p.optInt("off_count", "offCount", "inactive_count")
                        let pNew = p.optInt("unconfirmed_count", "unconfirmedCount", "new_count")
                        let share = pTotal > 0 ? (Double(pActive) * 100.0 / Double(pTotal)) : 0.0
                        return ProjectBreakdownRow(
                            id: p.optString("key", defaultValue: "\(name)_\(idx)"),
                            projectName: name,
                            totalCount: pTotal,
                            activeCount: pActive,
                            inactiveCount: pInactive,
                            newCount: pNew,
                            activeSharePct: share
                        )
                    }

                    let byRecruiterObj = (dimsObj["by_recruiter"] as? [String: Any])
                        ?? (dimsObj["byRecruiter"] as? [String: Any]) ?? [:]
                    let recruitersBuckets = byRecruiterObj.optObjectArray("buckets")
                    let recruiters: [PersonPerformanceRow] = recruitersBuckets.enumerated().map { idx, r in
                        let rTotal = r.optInt("eligible_episode_count", "eligibleEpisodeCount", "total_workers", "total")
                        let rActive = r.optInt("on_count", "onCount", "active_count")
                        let rInactive = r.optInt("off_count", "offCount", "inactive_count")
                        let rate = rTotal > 0 ? (Double(rActive) * 100.0 / Double(rTotal)) : 0.0
                        let key = r.optString("key", "recruiter_id", "code", defaultValue: "rec_\(idx)")
                        return PersonPerformanceRow(
                            id: key,
                            code: key,
                            name: r.optString("display", "recruiter_display", "name", "full_name", defaultValue: "NV #\(idx + 1)"),
                            totalCount: rTotal,
                            activeCount: rActive,
                            inactiveCount: rInactive,
                            activeRatePct: rate
                        )
                    }

                    let managers: [PersonPerformanceRow] = teamBuckets.enumerated().map { idx, m in
                        let mTotal = m.optInt("eligible_episode_count", "eligibleEpisodeCount", "total_workers", "total")
                        let mActive = m.optInt("on_count", "onCount", "active_count")
                        let mInactive = m.optInt("off_count", "offCount", "inactive_count")
                        let rate = mTotal > 0 ? (Double(mActive) * 100.0 / Double(mTotal)) : 0.0
                        let key = m.optString("key", "team_id", "code", defaultValue: "team_\(idx)")
                        return PersonPerformanceRow(
                            id: key,
                            code: key,
                            name: m.optString("display", "team_display", "name", defaultValue: "Nhóm #\(idx + 1)"),
                            totalCount: mTotal,
                            activeCount: mActive,
                            inactiveCount: mInactive,
                            activeRatePct: rate
                        )
                    }

                    return .success(
                        GeneralOverviewData(
                            scope: scope,
                            kpis: kpis,
                            projects: projects,
                            projectsTotal: totalProjectCount,
                            projectsPage: projectsPage,
                            projectsTotalPages: 1,
                            recruiters: recruiters,
                            managers: managers
                        ),
                        statusCode: response.statusCode
                    )
                }

                // Legacy/unit-test fallback format (`root["report"]` / `root["kpis"]`)
                let reportObj = (root["report"] as? [String: Any])
                    ?? (root["data"] as? [String: Any])
                    ?? root
                let kpisObj = (reportObj["kpis"] as? [String: Any])
                    ?? (reportObj["summary"] as? [String: Any])
                    ?? reportObj

                let totalWorkers = kpisObj.optInt("total_workers", "total_headcount", "total")
                let activeCount = kpisObj.optInt("on_count", "active_count", "working_count", "active")
                let inactiveCount = kpisObj.optInt("off_count", "inactive_count", "resigned_count", "inactive")
                let unconfirmedCount = kpisObj.optInt("unconfirmed_count", "interview_count", "interview")
                let newCount = kpisObj.optInt("new_in_period_count", "new_count", "new_workers")
                let resignedInPeriodCount = kpisObj.optInt("off_in_period_count", "resigned_in_period_count", "resigned_period")
                let retentionRate = totalWorkers > 0
                    ? (Double(activeCount) * 100.0 / Double(totalWorkers))
                    : kpisObj.optDouble("retention_rate", "active_rate")
                let turnoverRate = totalWorkers > 0
                    ? (Double(inactiveCount) * 100.0 / Double(totalWorkers))
                    : kpisObj.optDouble("turnover_rate")

                let projectsRaw = reportObj.optObjectArray("by_project").ifEmpty(reportObj.optObjectArray("projects"))
                let projects: [ProjectBreakdownRow] = projectsRaw.enumerated().map { idx, p in
                    let name = p.optString("project_display", "du_an", "project_name", "name", "project_id", defaultValue: "Dự án #\(idx + 1)")
                    let pTotal = p.optInt("total_workers", "total_count", "total")
                    let pActive = p.optInt("on_count", "active_count", "active")
                    let pInactive = p.optInt("off_count", "inactive_count", "inactive")
                    let pNew = p.optInt("new_count", "new")
                    let share = pTotal > 0 ? (Double(pActive) * 100.0 / Double(pTotal)) : p.optDouble("active_share_pct", "active_rate")
                    return ProjectBreakdownRow(
                        id: "\(name)_\(idx)",
                        projectName: name,
                        totalCount: pTotal,
                        activeCount: pActive,
                        inactiveCount: pInactive,
                        newCount: pNew,
                        activeSharePct: share
                    )
                }

                let recruitersRaw = reportObj.optObjectArray("by_recruiter").ifEmpty(reportObj.optObjectArray("recruiters"))
                let recruiters: [PersonPerformanceRow] = recruitersRaw.enumerated().map { idx, r in
                    let rTotal = r.optInt("total_workers", "total_count", "total")
                    let rActive = r.optInt("on_count", "active_count", "active")
                    let rInactive = r.optInt("off_count", "inactive_count", "inactive")
                    let rate = rTotal > 0 ? (Double(rActive) * 100.0 / Double(rTotal)) : r.optDouble("active_rate_pct", "active_rate")
                    return PersonPerformanceRow(
                        id: r.optString("recruiter_id", "code", "username", defaultValue: "rec_\(idx)"),
                        code: r.optString("recruiter_id", "code", "username"),
                        name: r.optString("recruiter_display", "name", "full_name", "nguoi_tuyen", defaultValue: "NV #\(idx + 1)"),
                        totalCount: rTotal,
                        activeCount: rActive,
                        inactiveCount: rInactive,
                        activeRatePct: rate
                    )
                }

                let overview = GeneralOverviewData(
                    scope: scope,
                    kpis: GeneralOverviewKpis(
                        totalHeadcount: totalWorkers,
                        activeCount: activeCount,
                        inactiveCount: inactiveCount,
                        interviewCount: unconfirmedCount,
                        newCount: newCount,
                        resignedInPeriodCount: resignedInPeriodCount,
                        retentionRate: retentionRate,
                        turnoverRate: turnoverRate
                    ),
                    projects: projects,
                    projectsTotal: projects.count,
                    projectsPage: projectsPage,
                    projectsTotalPages: 1,
                    recruiters: recruiters,
                    managers: []
                )
                return .success(overview, statusCode: response.statusCode)
            }

            if response.statusCode != 403 && response.statusCode != 404 {
                return .failure(
                    message: response.errorMessage ?? "Không thể tải báo cáo tổng quát.",
                    httpStatus: response.statusCode,
                    errorCode: response.errorCode
                )
            }
        }

        // Scoped or non-Admin fallback: aggregate from `/api/direct-entry/workers`
        if let fallbackData = await fetchMergedWorkersForScopedFallback(
            preferredScope: scope,
            allowedWorkerScopes: allowedWorkerScopes,
            startDate: startDate,
            endDate: endDate
        ) {
            let items = fallbackData.items
            let isWorking: (WorkerItem) -> Bool = { w in
                let st = w.trangThai.lowercased()
                return !st.contains("nghỉ") && !st.contains("off") && !st.contains("chưa")
            }
            let isOff: (WorkerItem) -> Bool = { w in
                let st = w.trangThai.lowercased()
                return st.contains("nghỉ") || st == "off"
            }
            let total = max(fallbackData.total, items.count)
            let active = items.filter { isWorking($0) }.count
            let inactive = items.filter { isOff($0) }.count
            let interview = max(0, items.count - active - inactive)
            let retention = items.isEmpty ? 0.0 : (Double(active) * 100.0 / Double(items.count))
            let turnover = items.isEmpty ? 0.0 : (Double(inactive) * 100.0 / Double(items.count))

            var byProject: [String: (total: Int, active: Int, inactive: Int)] = [:]
            var byRecruiter: [String: (total: Int, active: Int, inactive: Int)] = [:]
            for w in items {
                let pName = w.duAn.isEmpty ? "Chưa phân dự án" : w.duAn
                var pCur = byProject[pName] ?? (0, 0, 0)
                pCur.total += 1
                if isWorking(w) { pCur.active += 1 } else if isOff(w) { pCur.inactive += 1 }
                byProject[pName] = pCur

                let rName = w.nguoiTuyen.isEmpty ? "Chưa gán người tuyển" : w.nguoiTuyen
                var rCur = byRecruiter[rName] ?? (0, 0, 0)
                rCur.total += 1
                if isWorking(w) { rCur.active += 1 } else if isOff(w) { rCur.inactive += 1 }
                byRecruiter[rName] = rCur
            }

            let projects = byProject.sorted { $0.value.total > $1.value.total }.enumerated().map { idx, kv in
                ProjectBreakdownRow(
                    id: "proj_\(idx)",
                    projectName: kv.key,
                    totalCount: kv.value.total,
                    activeCount: kv.value.active,
                    inactiveCount: kv.value.inactive,
                    newCount: 0,
                    activeSharePct: kv.value.total > 0 ? (Double(kv.value.active) * 100.0 / Double(kv.value.total)) : 0.0
                )
            }
            let recruiters = byRecruiter.sorted { $0.value.total > $1.value.total }.enumerated().map { idx, kv in
                PersonPerformanceRow(
                    id: "rec_\(idx)",
                    code: kv.key,
                    name: kv.key,
                    totalCount: kv.value.total,
                    activeCount: kv.value.active,
                    inactiveCount: kv.value.inactive,
                    activeRatePct: kv.value.total > 0 ? (Double(kv.value.active) * 100.0 / Double(kv.value.total)) : 0.0
                )
            }

            return .success(
                GeneralOverviewData(
                    scope: scope,
                    kpis: GeneralOverviewKpis(
                        totalHeadcount: total,
                        activeCount: active,
                        inactiveCount: inactive,
                        interviewCount: interview,
                        newCount: hasDateFilter ? total : 0,
                        resignedInPeriodCount: hasDateFilter ? inactive : 0,
                        retentionRate: retention,
                        turnoverRate: turnover
                    ),
                    projects: projects,
                    projectsTotal: projects.count,
                    projectsPage: 1,
                    projectsTotalPages: 1,
                    recruiters: recruiters,
                    managers: []
                ),
                statusCode: fallbackData.statusCode
            )
        }

        return .failure(message: "Không tải được báo cáo tổng quát.")
    }

    public func fetchWorkforceDeepMetrics(
        scope: String = "all",
        allowedWorkerScopes: [String] = [],
        startDate: String? = nil,
        endDate: String? = nil
    ) async -> MiniBiApiResult<WorkforceDeepMetricsData> {
        let cleanStart = (startDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEnd = (endDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let hasDateFilter = !cleanStart.isEmpty || !cleanEnd.isEmpty

        let response = await fetchCoalescedWorkforceDeepResponse(
            startDate: cleanStart,
            endDate: cleanEnd
        )

        if response.isSuccess, let root = response.jsonObject {
            if let wfObj = root["workforce"] as? [String: Any] {
                let snapshotObj = (wfObj["snapshot"] as? [String: Any]) ?? [:]
                let totalEp = max(1, snapshotObj.optInt("eligible_episode_total", "eligibleEpisodeTotal", defaultValue: 1))
                let onCount = snapshotObj.optInt("on_count", "onCount")
                let offCount = snapshotObj.optInt("off_count", "offCount")
                let unconfirmedCount = snapshotObj.optInt("unconfirmed_count", "unconfirmedCount")

                let balanceObj = (wfObj["balance"] as? [String: Any]) ?? [:]
                let balanceApplicable = balanceObj.optBool("applicable", defaultValue: false)
                let newEpObj = (balanceObj["new_episodes_in_period"] as? [String: Any])
                    ?? (balanceObj["newEpisodesInPeriod"] as? [String: Any]) ?? [:]
                let byStatusObj = (balanceObj["by_status"] as? [String: Any])
                    ?? (balanceObj["byStatus"] as? [String: Any]) ?? [:]
                let onFlowObj = (byStatusObj["on"] as? [String: Any]) ?? [:]
                let offFlowObj = (byStatusObj["off"] as? [String: Any]) ?? [:]
                let waitingFlowObj = (byStatusObj["unconfirmed"] as? [String: Any]) ?? [:]

                let retentionObj = (wfObj["retention"] as? [String: Any]) ?? [:]
                let checkpointsObj = (retentionObj["checkpoints"] as? [String: Any]) ?? [:]
                var tenureBuckets: [DistributionBucket] = []

                if hasDateFilter {
                    let periodCohortObj = (retentionObj["period_cohort"] as? [String: Any])
                        ?? (retentionObj["periodCohort"] as? [String: Any]) ?? [:]
                    let cohortSize = periodCohortObj.optInt("cohort_size", "cohortSize")
                    if cohortSize > 0 {
                        tenureBuckets.append(
                            DistributionBucket(
                                id: "period_cohort_size",
                                label: "Nhóm tuyển mới trong kỳ",
                                count: cohortSize,
                                percentage: 100.0
                            )
                        )
                        let pCpObj = (periodCohortObj["checkpoints"] as? [String: Any]) ?? [:]
                        for (key, title) in [
                            ("d7", "Giữ chân D7 (nhóm trong kỳ)"),
                            ("d30", "Giữ chân D30 (nhóm trong kỳ)"),
                            ("d90", "Giữ chân D90 (nhóm trong kỳ)")
                        ] {
                            if let cp = pCpObj[key] as? [String: Any] {
                                let eligible = cp.optInt("eligible_count", "eligibleCount")
                                let retained = cp.optInt("retained_count", "retainedCount")
                                if eligible > 0 {
                                    let rawRate = cp.optDouble("retention_rate", "retentionRate")
                                    let pct = rawRate <= 1.0 && rawRate > 0.0 ? rawRate * 100.0 : rawRate
                                    tenureBuckets.append(
                                        DistributionBucket(
                                            id: "period_\(key)",
                                            label: "\(title) (\(retained)/\(eligible))",
                                            count: retained,
                                            percentage: pct
                                        )
                                    )
                                }
                            }
                        }
                    }
                }

                let durationObj = (wfObj["duration"] as? [String: Any]) ?? [:]
                let distRaw = durationObj.optObjectArray("distribution")
                let durationTotal = max(1, distRaw.reduce(0) { $0 + $1.optInt("episode_count", "episodeCount", "count") })
                let durationLabels: [String: String] = [
                    "0_7_days": "Thâm niên 0–7 ngày",
                    "8_30_days": "Thâm niên 8–30 ngày",
                    "31_90_days": "Thâm niên 31–90 ngày",
                    "90_plus_days": "Thâm niên trên 90 ngày"
                ]
                for (idx, b) in distRaw.enumerated() {
                    let key = b.optString("bucket", "key", defaultValue: "dur_\(idx)")
                    let cnt = b.optInt("episode_count", "episodeCount", "count")
                    if cnt > 0 {
                        let rawShare = b.optDouble("share_rate", "shareRate")
                        let pct = rawShare > 0.0
                            ? (rawShare <= 1.0 ? rawShare * 100.0 : rawShare)
                            : (Double(cnt) * 100.0 / Double(durationTotal))
                        tenureBuckets.append(
                            DistributionBucket(
                                id: "dur_\(key)",
                                label: durationLabels[key] ?? key,
                                count: cnt,
                                percentage: pct
                            )
                        )
                    }
                }

                for (key, title) in [
                    ("d7", "Giữ chân sau 7 ngày (D7 lũy kế)"),
                    ("d30", "Giữ chân sau 30 ngày (D30 lũy kế)"),
                    ("d90", "Giữ chân sau 90 ngày (D90 lũy kế)")
                ] {
                    if let cp = checkpointsObj[key] as? [String: Any] {
                        let retained = cp.optInt("retained_count", "retainedCount")
                        let rawRate = cp.optDouble("retention_rate", "retentionRate")
                        let pct = rawRate <= 1.0 && rawRate > 0.0 ? rawRate * 100.0 : rawRate
                        tenureBuckets.append(DistributionBucket(id: key, label: title, count: retained, percentage: pct))
                    }
                }

                let dimsObj = (wfObj["dimensions"] as? [String: Any]) ?? [:]
                let byTeamObj = (dimsObj["by_team"] as? [String: Any]) ?? (dimsObj["byTeam"] as? [String: Any]) ?? [:]
                let teamBucketsRaw = byTeamObj.optObjectArray("buckets")

                let periodAgg: PeriodAllScopeAggregation? = hasDateFilter
                    ? await fetchCoalescedPeriodAggregation(
                        teamBucketsRaw: teamBucketsRaw,
                        startDate: cleanStart,
                        endDate: cleanEnd
                    )
                    : nil

                let byProviderObj = (dimsObj["by_provider"] as? [String: Any]) ?? (dimsObj["byProvider"] as? [String: Any]) ?? [:]
                let providerBucketsRaw = byProviderObj.optObjectArray("buckets")
                let providerBuckets: [DistributionBucket] = {
                    if let periodAgg, hasDateFilter, !periodAgg.providerBuckets.isEmpty {
                        return periodAgg.providerBuckets
                    }
                    return providerBucketsRaw.enumerated().map { idx, b in
                        let cnt = b.optInt("eligible_episode_count", "eligibleEpisodeCount", "on_count")
                        let pct = Double(cnt) * 100.0 / Double(totalEp)
                        return DistributionBucket(
                            id: b.optString("key", defaultValue: "prov_\(idx)"),
                            label: b.optString("display", "label", "key", defaultValue: "Nguồn \(idx + 1)"),
                            count: cnt,
                            percentage: pct
                        )
                    }
                }()

                let teamBuckets: [DistributionBucket] = {
                    if let periodAgg, hasDateFilter, !periodAgg.teamBuckets.isEmpty {
                        return periodAgg.teamBuckets
                    }
                    return teamBucketsRaw.enumerated().map { idx, b in
                        let cnt = b.optInt("eligible_episode_count", "eligibleEpisodeCount", "on_count")
                        let pct = Double(cnt) * 100.0 / Double(totalEp)
                        return DistributionBucket(
                            id: b.optString("key", defaultValue: "team_\(idx)"),
                            label: b.optString("display", "label", "key", defaultValue: "Nhóm \(idx + 1)"),
                            count: cnt,
                            percentage: pct
                        )
                    }
                }()

                let statusBuckets: [DistributionBucket] = {
                    if hasDateFilter && balanceApplicable {
                        let newCount = newEpObj.optInt("total", "count")
                        let onInflow = onFlowObj.optInt("total_inflow_count", "totalInflowCount", "count")
                        let waitingInflow = waitingFlowObj.optInt("total_inflow_count", "totalInflowCount", "count")
                        let offInflow = offFlowObj.optInt("total_inflow_count", "totalInflowCount", "count")
                        let denom = Double(max(1, max(newCount, onInflow + waitingInflow + offInflow)))
                        return [
                            DistributionBucket(
                                id: "PERIOD_NEW",
                                label: "Tuyển mới trong kỳ",
                                count: newCount,
                                percentage: min(100.0, Double(newCount) * 100.0 / denom)
                            ),
                            DistributionBucket(
                                id: "PERIOD_ON",
                                label: "Vào làm (ON) trong kỳ",
                                count: onInflow,
                                percentage: min(100.0, Double(onInflow) * 100.0 / denom)
                            ),
                            DistributionBucket(
                                id: "PERIOD_UNCONFIRMED",
                                label: "Chờ nhận việc trong kỳ",
                                count: waitingInflow,
                                percentage: min(100.0, Double(waitingInflow) * 100.0 / denom)
                            ),
                            DistributionBucket(
                                id: "PERIOD_OFF",
                                label: "Nghỉ việc (OFF) trong kỳ",
                                count: offInflow,
                                percentage: min(100.0, Double(offInflow) * 100.0 / denom)
                            )
                        ]
                    }
                    return [
                        DistributionBucket(id: "ON", label: "Đang làm việc (ON)", count: onCount, percentage: Double(onCount) * 100.0 / Double(totalEp)),
                        DistributionBucket(id: "UNCONFIRMED", label: "Chờ nhận việc (UNCONFIRMED)", count: unconfirmedCount, percentage: Double(unconfirmedCount) * 100.0 / Double(totalEp)),
                        DistributionBucket(id: "OFF", label: "Đã nghỉ việc (OFF)", count: offCount, percentage: Double(offCount) * 100.0 / Double(totalEp))
                    ]
                }()

                let leaveReasonsObj = (wfObj["leave_reasons"] as? [String: Any]) ?? (wfObj["leaveReasons"] as? [String: Any]) ?? [:]
                let periodLeaveObj = (leaveReasonsObj["period_leave_reasons"] as? [String: Any])
                    ?? (leaveReasonsObj["periodLeaveReasons"] as? [String: Any]) ?? [:]
                let usePeriodLeave = hasDateFilter && periodLeaveObj.optBool("applicable", defaultValue: false)
                let leaveSourceObj = usePeriodLeave ? periodLeaveObj : leaveReasonsObj
                let leaveCatsRaw = leaveSourceObj.optObjectArray("by_category").ifEmpty(leaveSourceObj.optObjectArray("byCategory"))
                let resignBuckets: [DistributionBucket] = leaveCatsRaw.enumerated().compactMap { idx, c in
                    let cnt = c.optInt("episode_count", "episodeCount", "count")
                    guard cnt > 0 else { return nil }
                    let rawShare = c.optDouble(
                        "share_of_off_events_rate",
                        "shareOfOffEventsRate",
                        "share_of_off_rate",
                        "shareOfOffRate",
                        "percentage"
                    )
                    let pct = rawShare <= 1.0 && rawShare > 0.0 ? rawShare * 100.0 : rawShare
                    let rawKey = c.optString("category", "key", defaultValue: "leave_\(idx)")
                    let rawLabel = c.optString("label", "display")
                    return DistributionBucket(
                        id: rawKey,
                        label: Self.leaveCategoryLabelVi(rawKey, fallback: rawLabel),
                        count: cnt,
                        percentage: pct
                    )
                }

                return .success(
                    WorkforceDeepMetricsData(
                        tenureBuckets: tenureBuckets,
                        ageBuckets: teamBuckets,
                        genderBuckets: providerBuckets,
                        contractBuckets: statusBuckets,
                        resignReasonBuckets: resignBuckets
                    ),
                    statusCode: response.statusCode
                )
            }

            let dataObj = (root["report"] as? [String: Any])
                ?? (root["data"] as? [String: Any])
                ?? root

            func parseBuckets(_ key: String) -> [DistributionBucket] {
                let arr = dataObj.optObjectArray(key)
                return arr.enumerated().map { idx, b in
                    DistributionBucket(
                        id: "\(key)_\(idx)",
                        label: b.optString("label", "name", "bucket", "labor_type_display", "project_display", defaultValue: "Nhóm \(idx + 1)"),
                        count: b.optInt("count", "value", "total", "total_workers"),
                        percentage: b.optDouble("percentage", "pct", "share")
                    )
                }
            }

            let deepData = WorkforceDeepMetricsData(
                tenureBuckets: parseBuckets("tenure_buckets").ifEmpty(parseBuckets("tenure")).ifEmpty(parseBuckets("by_tenure")),
                ageBuckets: parseBuckets("age_buckets").ifEmpty(parseBuckets("age")).ifEmpty(parseBuckets("by_age")),
                genderBuckets: parseBuckets("gender_buckets").ifEmpty(parseBuckets("gender")).ifEmpty(parseBuckets("by_labor_type")),
                contractBuckets: parseBuckets("contract_buckets").ifEmpty(parseBuckets("contract_status")).ifEmpty(parseBuckets("by_status")),
                resignReasonBuckets: parseBuckets("resign_reason_buckets").ifEmpty(parseBuckets("resign_reasons"))
            )
            return .success(deepData, statusCode: response.statusCode)
        }

        if response.statusCode != 403 && response.statusCode != 404 {
            return .failure(
                message: response.errorMessage ?? "Không thể tải báo cáo chuyên sâu.",
                httpStatus: response.statusCode,
                errorCode: response.errorCode
            )
        }

        if let fallbackData = await fetchMergedWorkersForScopedFallback(
            preferredScope: scope,
            allowedWorkerScopes: allowedWorkerScopes,
            startDate: startDate,
            endDate: endDate
        ) {
            let items = fallbackData.items
            let total = max(1, items.count)
            var byStatus: [String: Int] = [:]
            var byLaborType: [String: Int] = [:]
            for w in items {
                byStatus[w.trangThai, default: 0] += 1
                let lt = w.nganhNghe.isEmpty ? "Thời vụ" : w.nganhNghe
                byLaborType[lt, default: 0] += 1
            }
            let contractBuckets = byStatus.sorted { $0.value > $1.value }.enumerated().map { idx, kv in
                DistributionBucket(id: "st_\(idx)", label: kv.key, count: kv.value, percentage: Double(kv.value) * 100.0 / Double(total))
            }
            let genderBuckets = byLaborType.sorted { $0.value > $1.value }.enumerated().map { idx, kv in
                DistributionBucket(id: "lt_\(idx)", label: kv.key, count: kv.value, percentage: Double(kv.value) * 100.0 / Double(total))
            }
            return .success(
                WorkforceDeepMetricsData(
                    tenureBuckets: [],
                    ageBuckets: [],
                    genderBuckets: genderBuckets,
                    contractBuckets: contractBuckets,
                    resignReasonBuckets: []
                ),
                statusCode: fallbackData.statusCode
            )
        }

        return .failure(
            message: response.errorMessage ?? "Không thể tải báo cáo chuyên sâu.",
            httpStatus: response.statusCode,
            errorCode: response.errorCode
        )
    }

    public func fetchTeamReport(
        allowedWorkerScopes: [String] = [],
        startDate: String? = nil,
        endDate: String? = nil,
        teamCode: String? = nil
    ) async -> MiniBiApiResult<TeamReportData> {
        let cleanStart = (startDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEnd = (endDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let hasDateFilter = !cleanStart.isEmpty || !cleanEnd.isEmpty

        let deepResponse = await fetchCoalescedWorkforceDeepResponse(
            startDate: cleanStart,
            endDate: cleanEnd
        )

        if deepResponse.isSuccess,
           let root = deepResponse.jsonObject,
           let wfObj = root["workforce"] as? [String: Any],
           let dimsObj = wfObj["dimensions"] as? [String: Any] {
            let byTeamObj = (dimsObj["by_team"] as? [String: Any]) ?? (dimsObj["byTeam"] as? [String: Any]) ?? [:]
            let teamBuckets = byTeamObj.optObjectArray("buckets")

            if hasDateFilter,
               let periodAgg = await fetchCoalescedPeriodAggregation(
                   teamBucketsRaw: teamBuckets,
                   startDate: cleanStart,
                   endDate: cleanEnd
               ),
               !periodAgg.teams.isEmpty {
                return .success(TeamReportData(teams: periodAgg.teams), statusCode: deepResponse.statusCode)
            }

            let teams: [TeamSummaryRow] = teamBuckets.enumerated().map { idx, b in
                let key = b.optString("key", "team_id", defaultValue: "team_\(idx)")
                let name = b.optString("display", "team_name", "name", defaultValue: key)
                let tTotal = b.optInt("eligible_episode_count", "eligibleEpisodeCount", "total")
                let tActive = b.optInt("on_count", "onCount", "active")
                let tInactive = b.optInt("off_count", "offCount", "inactive")
                let tNew = b.optInt("unconfirmed_count", "unconfirmedCount")
                let tRate = tTotal > 0 ? (Double(tActive) * 100.0 / Double(tTotal)) : 0.0
                return TeamSummaryRow(
                    id: key,
                    teamCode: key,
                    teamName: name,
                    leaderName: "",
                    memberCount: 0,
                    totalWorkers: tTotal,
                    activeWorkers: tActive,
                    inactiveWorkers: tInactive,
                    newWorkers: tNew,
                    activeRatePct: tRate,
                    members: []
                )
            }
            if !teams.isEmpty {
                return .success(TeamReportData(teams: teams), statusCode: deepResponse.statusCode)
            }
        }

        // Fallback for Team Leader / Scoped accounts: build team summary from `team` scope workers
        if let fallbackData = await fetchMergedWorkersForScopedFallback(
            preferredScope: "team",
            allowedWorkerScopes: allowedWorkerScopes,
            startDate: startDate,
            endDate: endDate
        ), !fallbackData.items.isEmpty {
            let items = fallbackData.items
            var byRecruiter: [String: (total: Int, active: Int, inactive: Int)] = [:]
            var activeTotal = 0
            var inactiveTotal = 0
            for w in items {
                let st = w.trangThai.lowercased()
                let isWork = !st.contains("nghỉ") && !st.contains("off") && !st.contains("chưa")
                let isOff = st.contains("nghỉ") || st == "off"
                if isWork { activeTotal += 1 } else if isOff { inactiveTotal += 1 }
                let rec = w.nguoiTuyen.isEmpty ? "Chưa gán người tuyển" : w.nguoiTuyen
                var cur = byRecruiter[rec] ?? (0, 0, 0)
                cur.total += 1
                if isWork { cur.active += 1 } else if isOff { cur.inactive += 1 }
                byRecruiter[rec] = cur
            }
            let members = byRecruiter.sorted { $0.value.total > $1.value.total }.enumerated().map { idx, kv in
                PersonPerformanceRow(
                    id: "mem_\(idx)",
                    code: kv.key,
                    name: kv.key,
                    totalCount: kv.value.total,
                    activeCount: kv.value.active,
                    inactiveCount: kv.value.inactive,
                    activeRatePct: kv.value.total > 0 ? (Double(kv.value.active) * 100.0 / Double(kv.value.total)) : 0.0
                )
            }
            let total = items.count
            let teamRow = TeamSummaryRow(
                id: "my_team",
                teamCode: "TEAM",
                teamName: "Nhóm phụ trách",
                leaderName: "",
                memberCount: members.count,
                totalWorkers: total,
                activeWorkers: activeTotal,
                inactiveWorkers: inactiveTotal,
                newWorkers: max(0, total - activeTotal - inactiveTotal),
                activeRatePct: total > 0 ? (Double(activeTotal) * 100.0 / Double(total)) : 0.0,
                members: members
            )
            return .success(TeamReportData(teams: [teamRow]), statusCode: fallbackData.statusCode)
        }

        return .success(TeamReportData(teams: []), statusCode: 200)
    }

    public func fetchDuplicateCccdReport(
        search: String = "",
        page: Int = 1,
        pageSize: Int = 15
    ) async -> MiniBiApiResult<DuplicateCccdReportData> {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(max(page, 1))),
            URLQueryItem(name: "page_size", value: String(min(max(pageSize, 1), 100))),
            URLQueryItem(name: "managed_only", value: "false")
        ]
        let cleanSearch = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanSearch.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: cleanSearch))
        }

        let response = await httpClient.request(
            method: "GET",
            path: "/api/direct-entry/duplicate-cccd-report",
            queryItems: queryItems
        )
        if response.statusCode == 403 || response.statusCode == 404 {
            return .success(DuplicateCccdReportData(), statusCode: response.statusCode)
        }
        guard response.isSuccess else {
            return .failure(
                message: response.errorMessage ?? "Không tải được báo cáo CCCD trùng.",
                httpStatus: response.statusCode,
                errorCode: response.errorCode
            )
        }

        let root = response.jsonObject ?? [:]
        let dataObj = (root["report"] as? [String: Any])
            ?? (root["data"] as? [String: Any])
            ?? root
        let groupsRaw = dataObj.optObjectArray("items").ifEmpty(dataObj.optObjectArray("groups"))

        let groups: [DuplicateCccdGroup] = groupsRaw.enumerated().map { idx, g in
            let last4 = g.optString("cccd_last4")
            let cccd = g.optString("national_id", "cccd", "so_cccd", defaultValue: last4.isEmpty ? "group_\(idx)" : "••••••••\(last4)")
            let epsRaw = g.optObjectArray("episodes").ifEmpty(g.optObjectArray("records")).ifEmpty(g.optObjectArray("entries"))
            let episodes: [DuplicateCccdEpisode] = epsRaw.enumerated().map { eIdx, e in
                let entryIdUuid = e.optString("entry_id", "id")
                let epId = e.optInt64("episode_id", "entry_id", "id") ?? Int64(idx * 1000 + eIdx + 1)
                let entryVer = e.optInt("entry_version", "version", defaultValue: 1)
                let empCode = e.optString("employee_code", "ma_nld", "worker_code")
                return DuplicateCccdEpisode(
                    id: entryIdUuid.isEmpty ? "\(cccd)_\(epId)" : entryIdUuid,
                    episodeId: epId,
                    entryIdUuid: entryIdUuid,
                    entryVersion: entryVer,
                    maNld: empCode.isEmpty ? entryIdUuid : empCode,
                    hoTen: e.optString("display_name", "ho_ten", "full_name"),
                    duAn: e.optString("project_display", "du_an", "project_name"),
                    quanLy: e.optString("quan_ly", "manager_name"),
                    nguoiTuyen: e.optString("recruiter_display", "nguoi_tuyen", "recruiter_name"),
                    trangThai: e.optString("latest_status", "employment_status", "trang_thai", "status"),
                    ngayVaoLam: e.optString("first_work_date", "ngay_vao_lam", "start_date"),
                    canSelfWithdraw: e.optBool("can_self_withdraw", "allow_withdraw", defaultValue: false)
                )
            }
            return DuplicateCccdGroup(
                id: "\(cccd)_\(idx)",
                cccd: cccd,
                workerCount: g.optInt("profile_count", "worker_count", "count", defaultValue: episodes.count),
                activeCount: g.optInt("active_profile_count", "active_count", "on_count", "active"),
                episodes: episodes
            )
        }

        let totalGroups = dataObj.optInt("total_groups", "total", defaultValue: groups.count)
        let currentPage = dataObj.optInt("page", defaultValue: page)
        let totalPages = max(1, dataObj.optInt("total_pages", defaultValue: 1))

        return .success(
            DuplicateCccdReportData(
                totalGroups: totalGroups,
                groups: groups,
                page: currentPage,
                totalPages: totalPages
            ),
            statusCode: response.statusCode
        )
    }

    public func selfWithdrawDuplicateEpisode(
        episodeId: Int64,
        cccd: String,
        maNld: String,
        entryVersion: Int = 1
    ) async -> MiniBiApiResult<Bool> {
        let idempotencyKey = UUID().uuidString.lowercased()
        let body: [String: Any] = [
            "entry_id": maNld,
            "expected_entry_version": max(1, entryVersion),
            "idempotency_key": idempotencyKey,
            "reason": NSNull()
        ]
        let response = await httpClient.request(
            method: "POST",
            path: "/api/direct-entry/duplicate-cccd-report/self-withdraw",
            jsonBody: body,
            additionalHeaders: ["Idempotency-Key": idempotencyKey]
        )
        guard response.isSuccess else {
            return .failure(
                message: response.errorMessage ?? "Rút hồ sơ trùng thất bại.",
                httpStatus: response.statusCode,
                errorCode: response.errorCode
            )
        }
        return .success(true, statusCode: response.statusCode)
    }

    // MARK: - Parsers

    private static func extractFormPayloadStrings(_ rawDict: [String: Any]) -> [String: String] {
        var formPayload: [String: String] = [:]
        for (k, v) in rawDict {
            guard !(v is NSNull) else { continue }
            if let s = v as? String {
                formPayload[k] = s
            } else if let b = v as? Bool {
                formPayload[k] = b ? "true" : "false"
            } else if let n = v as? NSNumber {
                if CFGetTypeID(n) == CFBooleanGetTypeID() {
                    formPayload[k] = n.boolValue ? "true" : "false"
                } else {
                    formPayload[k] = n.stringValue
                }
            } else if let arr = v as? [Any] {
                let strs = arr.compactMap { elem -> String? in
                    if let s = elem as? String { return s }
                    if let n = elem as? NSNumber { return n.stringValue }
                    return nil
                }
                formPayload[k] = strs.joined(separator: ",")
            }
        }
        return formPayload
    }

    private static func deterministicIdHash(_ rawUuid: String) -> Int64 {
        let trimmed = rawUuid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        var hash: UInt64 = 14695981039346656037
        for byte in trimmed.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return Int64(hash & 0x7FFF_FFFF_FFFF_FFFF)
    }

    public static func parseObligationItem(
        _ obj: [String: Any],
        fallbackRoot: [String: Any]? = nil,
        fallback: WorkReportObligationItem? = nil
    ) -> WorkReportObligationItem {
        let dataRoot = (fallbackRoot?["data"] as? [String: Any])
            ?? (obj["data"] as? [String: Any])
            ?? fallbackRoot
            ?? obj
        let obObj = (obj["obligation"] as? [String: Any])
            ?? (dataRoot["obligation"] as? [String: Any])
            ?? obj

        let obligationIdUuid = obObj.optString("obligation_id", "id")
            .ifEmpty(dataRoot.optString("obligation_id", "id"))
            .ifEmpty(fallback?.obligationIdUuid ?? "")
        let obligationId: Int64 = obObj.optInt64("obligation_id", "id")
            ?? dataRoot.optInt64("obligation_id", "id")
            ?? (fallback?.id != 0 ? fallback?.id : nil)
            ?? deterministicIdHash(obligationIdUuid)

        let templateObj = (obObj["template"] as? [String: Any])
            ?? (dataRoot["template"] as? [String: Any])
        let submissionObj = (obObj["submission"] as? [String: Any])
            ?? (dataRoot["submission"] as? [String: Any])
        let latestReviewObj = (obObj["latest_review_event"] as? [String: Any])
            ?? (dataRoot["latest_review_event"] as? [String: Any])
        let revisionsArr = dataRoot.optObjectArray("revisions")
            .ifEmpty(obObj.optObjectArray("revisions"))

        let submissionIdUuid = obObj.optNullableString("submission_id")
            ?? submissionObj?.optNullableString("submission_id", "id")
            ?? dataRoot.optNullableString("submission_id")
            ?? fallback?.submissionIdUuid
        let submissionId = obObj.optInt64("submission_id")
            ?? submissionObj?.optInt64("id", "submission_id")
            ?? dataRoot.optInt64("submission_id")
            ?? fallback?.submissionId

        let templateCode = obObj.optString(
            "template_code",
            defaultValue: templateObj?.optString("template_code", "code")
                .ifEmpty(fallback?.templateCode ?? "") ?? ""
        )
        let templateName = obObj.optString(
            "template_display_name",
            "template_name",
            "display_name",
            "title",
            defaultValue: templateObj?.optString("display_name", "template_display_name", "name", "title")
                .ifEmpty(fallback?.templateName ?? "Báo cáo công việc")
                ?? "Báo cáo công việc"
        )
        let periodType = obObj.optString(
            "period_type",
            defaultValue: templateObj?.optString("period_type")
                .ifEmpty(fallback?.periodType ?? "WEEKLY")
                ?? "WEEKLY"
        )
        let periodKey = obObj.optString("period_key", "period")
            .ifEmpty(fallback?.periodKey ?? "")
        let dueAt = obObj.optNullableString("due_at", "deadline_at")
            ?? fallback?.dueAt
        let obligationStatus = (
            obObj.optNullableString("obligation_status")
            ?? dataRoot.optNullableString("obligation_status")
            ?? fallback?.obligationStatus
            ?? WorkReportsContract.obligationStatusActive
        ).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let submissionState = (
            submissionObj?.optNullableString("state", "submission_state", "status")
            ?? obObj.optNullableString("submission_state", "state", "status")
            ?? fallback?.submissionState
            ?? WorkReportsContract.stateNotStarted
        ).uppercased()

        // Strictly read `is_overdue` from server (backward compatible default `false`)
        let isOverdue = obObj.optBool(
            "is_overdue",
            defaultValue: dataRoot.optBool("is_overdue", defaultValue: fallback?.isOverdue ?? false)
        )

        // Never fall back to `obObj["version"]` because `obligation.version` is 1 even when `submission_version` is null!
        let explicitSubVersion: Int? = {
            if let v = submissionObj?.optInt("version", "submission_version", defaultValue: -1), v > 0 {
                return v
            }
            if let v = obObj.optInt("submission_version", defaultValue: -1) as Int?, v > 0 {
                return v
            }
            return nil
        }()
        let version = explicitSubVersion ?? obObj.optInt("version", defaultValue: fallback?.version ?? 1)

        let submittedAt = submissionObj?.optNullableString("submitted_at", "last_submitted_at", "updated_at")
            ?? obObj.optNullableString("submitted_at", "last_submitted_at")
            ?? fallback?.submittedAt
        let reviewedAt = latestReviewObj?.optNullableString("created_at", "reviewed_at")
            ?? submissionObj?.optNullableString("reviewed_at")
            ?? obObj.optNullableString("reviewed_at")
            ?? fallback?.reviewedAt
        let reviewerName = latestReviewObj?.optNullableString("actor_display_name", "reviewer_name", "reviewed_by_name")
            ?? obObj.optNullableString("reviewer_name", "reviewed_by_name", "reviewer_display_name")
            ?? submissionObj?.optNullableString("reviewer_name", "reviewed_by_name", "reviewer_display_name")
            ?? fallback?.reviewerName
        let reviewComment = latestReviewObj?.optNullableString("reason", "review_note", "comment")
            ?? obObj.optNullableString("latest_rejection_reason", "review_note", "review_comment", "reject_reason", "comment")
            ?? submissionObj?.optNullableString("latest_rejection_reason", "review_note", "review_comment", "reject_reason", "comment")
            ?? fallback?.reviewComment
        let unitName = obObj.optNullableString("org_unit_name", "unit_name", "department_name")
            ?? fallback?.unitName
        let assigneeUserId = obObj.optString("assignee_user_id", "subject_user_id", "app_user_id", "user_id")
            .ifEmpty(dataRoot.optString("assignee_user_id", "subject_user_id", "app_user_id", "user_id"))
            .ifEmpty(fallback?.assigneeUserId ?? "")
        let assigneeDisplayName = obObj.optString("assignee_display_name", "subject_display_name", "assignee_name", "employee_display_name")
            .ifEmpty(dataRoot.optString("assignee_display_name", "subject_display_name", "assignee_name", "employee_display_name"))
            .ifEmpty(fallback?.assigneeDisplayName ?? "")

        let schemaRaw: Any? = obObj["schema_json"]
            ?? obObj["schema"]
            ?? obObj["form_schema"]
            ?? templateObj?["schema_json"]
            ?? templateObj?["schema"]
            ?? templateObj?["form_schema"]
            ?? dataRoot["schema_json"]
            ?? dataRoot["schema"]
            ?? dataRoot["form_schema"]
        let parsedSections = WorkReportsContract.parseDynamicSections(schemaRaw)
        let sections = parsedSections.isEmpty ? (fallback?.sections ?? []) : parsedSections

        let latestRevisionPayload: [String: Any]? = {
            guard !revisionsArr.isEmpty else { return nil }
            let bestRev = revisionsArr.max {
                $0.optInt("revision_no", defaultValue: 0) < $1.optInt("revision_no", defaultValue: 0)
            }
            return (bestRev?["payload_json"] as? [String: Any])
                ?? (bestRev?["payload"] as? [String: Any])
        }()

        let rawPayloadDict = (submissionObj?["draft_payload_json"] as? [String: Any])
            ?? (submissionObj?["payload_json"] as? [String: Any])
            ?? (submissionObj?["form_payload"] as? [String: Any])
            ?? (submissionObj?["payload"] as? [String: Any])
            ?? (submissionObj?["answers"] as? [String: Any])
            ?? latestRevisionPayload
            ?? (obObj["draft_payload_json"] as? [String: Any])
            ?? (obObj["payload_json"] as? [String: Any])
            ?? (obObj["form_payload"] as? [String: Any])
            ?? (obObj["payload"] as? [String: Any])
            ?? (obObj["answers"] as? [String: Any])
            ?? [:]

        var formPayload = Self.extractFormPayloadStrings(rawPayloadDict)
        if formPayload.isEmpty, let fbPayload = fallback?.formPayload, !fbPayload.isEmpty {
            formPayload = fbPayload
        }

        // Seed schema defaults (and "false" for boolean toggles so untouched "Không" toggles are always explicit)
        for sec in sections {
            for field in sec.fields where formPayload[field.id] == nil {
                if let def = field.defaultValue, !def.isEmpty {
                    formPayload[field.id] = def
                } else if field.isBooleanType {
                    formPayload[field.id] = "false"
                }
            }
        }

        return WorkReportObligationItem(
            id: obligationId,
            obligationIdUuid: obligationIdUuid.isEmpty ? String(obligationId) : obligationIdUuid,
            submissionId: submissionId,
            submissionIdUuid: submissionIdUuid,
            submissionVersion: explicitSubVersion,
            templateCode: templateCode,
            templateName: templateName,
            periodType: periodType,
            periodKey: periodKey,
            dueAt: dueAt,
            obligationStatus: obligationStatus.isEmpty ? WorkReportsContract.obligationStatusActive : obligationStatus,
            submissionState: submissionState,
            isOverdue: isOverdue,
            version: max(1, version),
            submittedAt: submittedAt,
            reviewedAt: reviewedAt,
            reviewerName: reviewerName,
            reviewComment: reviewComment,
            unitName: unitName,
            assigneeUserId: assigneeUserId,
            assigneeDisplayName: assigneeDisplayName,
            sections: sections,
            formPayload: formPayload
        )
    }

    public static func parseReviewItem(_ obj: [String: Any]) -> WorkReportReviewItem {
        let submissionIdUuid = obj.optString("submission_id", "id")
        let obligationIdUuid = obj.optString("obligation_id", defaultValue: submissionIdUuid)
        let submissionId = obj.optInt64("submission_id", "id") ?? deterministicIdHash(submissionIdUuid)
        let obligationId = obj.optInt64("obligation_id") ?? deterministicIdHash(obligationIdUuid)
        let templateName = obj.optString("template_display_name", "template_name", "display_name", "title", defaultValue: "Báo cáo công việc")
        let periodType = obj.optString("period_type", defaultValue: "WEEKLY")
        let periodKey = obj.optString("period_key", "period")
        let reporterName = obj.optString("subject_display_name", "reporter_name", "author_name", "user_name", defaultValue: "Nhân sự")
        let reporterCode = obj.optString("subject_user_id", "reporter_code", "author_code", "username")
        let unitName = obj.optString("org_unit_name", "unit_name", "department_name")
        let submittedAt = obj.optNullableString("submitted_at", "last_submitted_at", "created_at")
        let submissionState = obj.optString("submission_state", "state", "status", defaultValue: WorkReportsContract.stateSubmitted)
        let version = max(1, obj.optInt("submission_version", "version", defaultValue: 1))
        let sections = WorkReportsContract.parseDynamicSections(
            obj["schema_json"] ?? obj["schema"] ?? obj["form_schema"] ?? (obj["template"] as? [String: Any])?["schema_json"]
        )

        let rawPayloadDict = (obj["payload_json"] as? [String: Any])
            ?? (obj["draft_payload_json"] as? [String: Any])
            ?? (obj["form_payload"] as? [String: Any])
            ?? (obj["payload"] as? [String: Any])
            ?? (obj["answers"] as? [String: Any])
            ?? [:]
        let formPayload = Self.extractFormPayloadStrings(rawPayloadDict)

        return WorkReportReviewItem(
            id: submissionId,
            submissionIdUuid: submissionIdUuid.isEmpty ? String(submissionId) : submissionIdUuid,
            obligationId: obligationId,
            obligationIdUuid: obligationIdUuid.isEmpty ? String(obligationId) : obligationIdUuid,
            templateName: templateName,
            periodType: periodType,
            periodKey: periodKey,
            reporterName: reporterName,
            reporterCode: reporterCode,
            unitName: unitName,
            submittedAt: submittedAt,
            submissionState: submissionState,
            version: version,
            sections: sections,
            formPayload: formPayload
        )
    }
}

private extension String {
    func ifEmpty(_ fallback: @autoclosure () -> String) -> String {
        isEmpty ? fallback() : self
    }
}

private extension Array {
    func ifEmpty(_ fallback: @autoclosure () -> [Element]) -> [Element] {
        isEmpty ? fallback() : self
    }
}

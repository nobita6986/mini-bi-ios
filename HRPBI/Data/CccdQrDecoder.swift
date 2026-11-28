import Foundation

// MARK: - Vietnamese CCCD QR, MRZ (ICAO 9303) & OCR Decoder
// Supports 2021 7-segment QR, 2024+ 11-segment Căn cước QR, 2021 Back-side MRZ (IDVNM...), and Front/Back OCR.

public struct CccdQrData: Equatable, Sendable {
    public let soCccd: String
    public let soCmndCu: String
    public let hoTen: String
    public let ngaySinh: String
    public let gioiTinh: String
    public let queQuan: String
    public let ngayCap: String
    public let rawQr: String

    public init(
        soCccd: String,
        soCmndCu: String = "",
        hoTen: String = "",
        ngaySinh: String = "",
        gioiTinh: String = "",
        queQuan: String = "",
        ngayCap: String = "",
        rawQr: String = ""
    ) {
        self.soCccd = soCccd
        self.soCmndCu = soCmndCu
        self.hoTen = hoTen
        self.ngaySinh = ngaySinh
        self.gioiTinh = gioiTinh
        self.queQuan = queQuan
        self.ngayCap = ngayCap
        self.rawQr = rawQr
    }
}

public enum CccdQrDecoder {
    private static let mojibakeMarkers = ["Ã", "Â", "Ä", "Å", "Æ", "á»", "áº", "Æ°", "Æ¡", "Ä‘", "Ä\u{0090}"]

    public static func parse(_ rawText: String?) -> CccdQrData? {
        guard let rawText else { return nil }
        let repaired = repairUtf8MojibakeIfNeeded(rawText)
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !repaired.isEmpty else { return nil }

        if repaired.contains("|") {
            let parts = repaired.components(separatedBy: "|").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let first = parts.first {
                let cccdDigits = first.filter { $0.isNumber }
                if DirectEntryContract.isValidCccd12(cccdDigits) {
                    let cmndCu = parts.count > 1 ? parts[1] : ""
                    let hoTen = parts.count > 2 ? normalizeSpaces(parts[2]) : ""
                    let ngaySinh = parts.count > 3 ? normalizeDateToUi(parts[3]) : ""
                    let gioiTinh = parts.count > 4 ? normalizeGenderToUi(parts[4]) : ""
                    let queQuan = parts.count > 5 ? normalizeSpaces(parts[5]) : ""
                    let ngayCap = parts.count > 6 ? normalizeDateToUi(parts[6]) : ""

                    return CccdQrData(
                        soCccd: cccdDigits,
                        soCmndCu: cmndCu,
                        hoTen: hoTen,
                        ngaySinh: ngaySinh,
                        gioiTinh: gioiTinh,
                        queQuan: queQuan,
                        ngayCap: ngayCap,
                        rawQr: repaired
                    )
                }
            }
        }

        let standaloneDigits = repaired.filter { $0.isNumber }
        if standaloneDigits.count == 12 && DirectEntryContract.isValidCccd12(standaloneDigits) {
            return CccdQrData(soCccd: standaloneDigits, rawQr: repaired)
        }

        if repaired.uppercased().contains("IDVNM"),
           let mrzParsed = parseFromRecognizedTextLines(repaired.components(separatedBy: .newlines)) {
            return mrzParsed
        }

        return nil
    }

    public static func applyToDraft(
        _ draft: NewWorkerEntryDraft,
        qrData: CccdQrData,
        onlyEmptyFields: Bool = false
    ) -> NewWorkerEntryDraft {
        var copy = draft
        if onlyEmptyFields {
            if copy.soCccd.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !qrData.soCccd.isEmpty {
                copy.soCccd = qrData.soCccd
            }
            let currentName = copy.hoTen.trimmingCharacters(in: .whitespacesAndNewlines)
            if currentName.isEmpty, !qrData.hoTen.isEmpty {
                copy.hoTen = qrData.hoTen
            } else if !currentName.isEmpty,
                      !qrData.hoTen.isEmpty,
                      !containsVietnameseDiacritics(currentName),
                      containsVietnameseDiacritics(qrData.hoTen),
                      foldVietnameseForComparison(currentName) == foldVietnameseForComparison(qrData.hoTen) {
                copy.hoTen = qrData.hoTen
            }
            if copy.ngaySinh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !qrData.ngaySinh.isEmpty {
                copy.ngaySinh = qrData.ngaySinh
            }
            if copy.gioiTinh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !qrData.gioiTinh.isEmpty {
                copy.gioiTinh = qrData.gioiTinh
            }
            if copy.queQuan.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !qrData.queQuan.isEmpty {
                copy.queQuan = qrData.queQuan
            }
            if copy.ngayCap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !qrData.ngayCap.isEmpty {
                copy.ngayCap = qrData.ngayCap
            }
            return copy
        }

        copy.soCccd = qrData.soCccd
        if !qrData.hoTen.isEmpty {
            copy.hoTen = qrData.hoTen
        }
        if !qrData.ngaySinh.isEmpty {
            copy.ngaySinh = qrData.ngaySinh
        }
        if !qrData.gioiTinh.isEmpty {
            copy.gioiTinh = qrData.gioiTinh
        }
        if !qrData.queQuan.isEmpty {
            copy.queQuan = qrData.queQuan
        }
        if !qrData.ngayCap.isEmpty {
            copy.ngayCap = qrData.ngayCap
        }
        return copy
    }

    // MARK: - ICAO 9303 TD1 MRZ & Vietnamese OCR Fallback (2021 CCCD)

    /// Standard ICAO Doc 9303 Modulo-10 check digit with repeating weights `[7, 3, 1]`.
    public static func computeMrzCheckDigit(_ input: String) -> Int? {
        let weights = [7, 3, 1]
        var sum = 0
        for (idx, scalar) in input.uppercased().unicodeScalars.enumerated() {
            let val: Int
            switch scalar.value {
            case 48...57: // '0'...'9'
                val = Int(scalar.value - 48)
            case 65...90: // 'A'...'Z'
                val = Int(scalar.value - 65) + 10
            case 60: // '<'
                val = 0
            default:
                return nil
            }
            sum += val * weights[idx % 3]
        }
        return sum % 10
    }

    /// Parses 3-line TD1 MRZ (`IDVNM...`) from recognized text lines using Modulo-10 checksum verification.
    public static func parseMrzFromLines(_ lines: [String]) -> CccdQrData? {
        let normalizedLines = lines
            .map { normalizeMrzLine($0) }
            .filter { !$0.isEmpty }

        guard !normalizedLines.isEmpty else { return nil }

        // 1. Locate valid TD1 Line 1: IDVNM + 9 digits [5..<14] + check [14] + 12-digit CCCD [15..<27]
        var matchedLine1Index: Int?
        var matchedLine1Text = ""
        var matchedCccd = ""

        for (idx, rawLine) in normalizedLines.enumerated() {
            guard let slice = extractLine1Candidate(from: rawLine), slice.count >= 27 else { continue }
            let chars = Array(slice)
            let docNum9 = sanitizeMrzDigits(String(chars[5..<14]))
            let docCheckStr = sanitizeMrzDigits(String(chars[14..<15]))
            let cccd12 = sanitizeMrzDigits(String(chars[15..<27]))

            guard docNum9.count == 9,
                  docCheckStr.count == 1,
                  let expectedCheck = Int(docCheckStr),
                  let computedCheck = computeMrzCheckDigit(docNum9),
                  computedCheck == expectedCheck,
                  DirectEntryContract.isValidCccd12(cccd12),
                  cccd12.hasSuffix(docNum9) else {
                continue
            }

            matchedLine1Index = idx
            matchedLine1Text = slice
            matchedCccd = cccd12
            break
        }

        guard let line1Index = matchedLine1Index, !matchedCccd.isEmpty else {
            return nil
        }

        // Determine birth century & fallback gender from 4th digit of 12-digit CCCD
        let fourthDigit = Array(matchedCccd)[3]
        let centuryAndGender: (century: Int, gender: String) = {
            switch fourthDigit {
            case "0": return (1900, "Nam")
            case "1": return (1900, "Nữ")
            case "2": return (2000, "Nam")
            case "3": return (2000, "Nữ")
            case "4": return (2100, "Nam")
            case "5": return (2100, "Nữ")
            default: return (1900, "")
            }
        }()

        // 2. Locate TD1 Line 2: YYMMDD [0..<6] + check [6] + sex [7] + ... + VNM [15..<18]
        var dobUi = ""
        var genderUi = centuryAndGender.gender
        var matchedLine2Index: Int?
        var matchedLine2Text = ""

        let candidateIndicesAfterLine1 = Array((line1Index + 1)..<normalizedLines.count)
        let line2SearchOrder = candidateIndicesAfterLine1 + Array(0..<line1Index)
        for idx in line2SearchOrder {
            let line = normalizedLines[idx]
            guard line.count >= 18 else { continue }
            let chars = Array(line)
            let nationality = String(chars[15..<18])
            guard nationality == "VNM" || nationality == "VNH" || nationality == "VNN" else { continue }
            let sexChar = chars[7]
            guard sexChar == "M" || sexChar == "F" || sexChar == "<" else { continue }

            let dob6 = sanitizeMrzDigits(String(chars[0..<6]))
            let dobCheckStr = sanitizeMrzDigits(String(chars[6..<7]))
            guard dob6.count == 6,
                  dobCheckStr.count == 1,
                  let expectedDobCheck = Int(dobCheckStr),
                  let computedDobCheck = computeMrzCheckDigit(dob6),
                  computedDobCheck == expectedDobCheck else {
                continue
            }

            let dobChars = Array(dob6)
            if let yy = Int(String(dobChars[0..<2])),
               let mm = Int(String(dobChars[2..<4])),
               let dd = Int(String(dobChars[4..<6])),
               (1...12).contains(mm),
               (1...31).contains(dd) {
                let fullYear = centuryAndGender.century + yy
                dobUi = String(format: "%02d/%02d/%04d", dd, mm, fullYear)
            }

            if sexChar == "M" {
                genderUi = "Nam"
            } else if sexChar == "F" {
                genderUi = "Nữ"
            }

            matchedLine2Index = idx
            matchedLine2Text = line
            break
        }

        // 3. Locate TD1 Line 3: DO<<THI<LAN<ANH<<<<<<<<<<<<<<<
        var mrzName = ""
        var matchedLine3Text = ""
        let line3Start = (matchedLine2Index ?? line1Index) + 1
        let line3SearchOrder = Array(line3Start..<normalizedLines.count) + Array(0..<min(line3Start, normalizedLines.count))
        for idx in line3SearchOrder where idx != line1Index && idx != matchedLine2Index {
            let line = normalizedLines[idx]
            guard line.contains("<<"),
                  !line.hasPrefix("IDVNM"),
                  !line.contains("VNM<<"),
                  line.unicodeScalars.allSatisfy({ ($0.value >= 65 && $0.value <= 90) || $0.value == 60 }) else {
                continue
            }
            let cleanedName = normalizeSpaces(
                line.replacingOccurrences(of: "<", with: " ")
            )
            if cleanedName.count >= 3 {
                mrzName = cleanedName
                matchedLine3Text = line
                break
            }
        }

        let rawLines = [matchedLine1Text, matchedLine2Text, matchedLine3Text].filter { !$0.isEmpty }
        return CccdQrData(
            soCccd: matchedCccd,
            hoTen: mrzName,
            ngaySinh: dobUi,
            gioiTinh: genderUi,
            rawQr: rawLines.joined(separator: "\n")
        )
    }

    /// Parses and merges MRZ + Vietnamese Front/Back OCR text lines (supports single-side or combined front+back photos).
    public static func parseFromRecognizedTextLines(_ lines: [String]) -> CccdQrData? {
        let cleanedLines = lines
            .map { normalizeSpaces(repairUtf8MojibakeIfNeeded($0)) }
            .filter { !$0.isEmpty }
        guard !cleanedLines.isEmpty else { return nil }

        let mrzData = parseMrzFromLines(cleanedLines)
        let ocr = extractVietnameseOcrFields(from: cleanedLines)

        let finalCccd = (mrzData?.soCccd.isEmpty == false ? mrzData?.soCccd : nil) ?? ocr.soCccd
        guard DirectEntryContract.isValidCccd12(finalCccd) else {
            return nil
        }

        let finalName = !ocr.hoTen.isEmpty ? ocr.hoTen : (mrzData?.hoTen ?? "")
        let finalDob = (mrzData?.ngaySinh.isEmpty == false ? mrzData?.ngaySinh : nil) ?? ocr.ngaySinh
        let finalGender = (mrzData?.gioiTinh.isEmpty == false ? mrzData?.gioiTinh : nil) ?? ocr.gioiTinh
        let finalRaw = (mrzData?.rawQr.isEmpty == false ? mrzData?.rawQr : nil) ?? "OCR:\(finalCccd)"

        return CccdQrData(
            soCccd: finalCccd,
            hoTen: finalName,
            ngaySinh: finalDob,
            gioiTinh: finalGender,
            queQuan: ocr.queQuan,
            ngayCap: ocr.ngayCap,
            rawQr: finalRaw
        )
    }

    private struct ExtractedOcrFields {
        var soCccd: String = ""
        var hoTen: String = ""
        var ngaySinh: String = ""
        var gioiTinh: String = ""
        var queQuan: String = ""
        var ngayCap: String = ""
    }

    private static func extractVietnameseOcrFields(from lines: [String]) -> ExtractedOcrFields {
        var result = ExtractedOcrFields()

        let foldedLines = lines.map { foldVietnameseForComparison($0) }

        func isMrzNoiseLine(_ folded: String) -> Bool {
            let compact = folded.replacingOccurrences(of: " ", with: "")
            return compact.contains("idvnm") || compact.contains("<<<") || compact.contains("<<")
        }

        func isKnownFieldLabel(_ folded: String) -> Bool {
            let markers = [
                "so /", "so/", "no.", "ho va ten", "full name",
                "ngay sinh", "date of birth", "gioi tinh", "sex",
                "quoc tich", "nationality", "que quan", "place of origin",
                "noi thuong tru", "place of residence", "co gia tri", "date of expiry",
                "dac diem", "personal identification", "ngay, thang", "ngay thang nam",
                "date, month", "ngay cap", "cuc truong", "director", "can cuoc cong dan",
                "citizen identity card", "cong hoa xa hoi"
            ]
            return markers.contains { folded.contains($0) }
        }

        // 1. Số CCCD (labeled first, then standalone)
        var standaloneCccdCandidate = ""
        for (idx, line) in lines.enumerated() {
            let folded = foldedLines[idx]
            if isMrzNoiseLine(folded) { continue }
            if let twelve = firstValidCccd12InString(line) {
                if folded.contains("so") || folded.contains("no.") || folded.contains("can cuoc") {
                    result.soCccd = twelve
                    break
                } else if standaloneCccdCandidate.isEmpty {
                    standaloneCccdCandidate = twelve
                }
            }
        }
        if result.soCccd.isEmpty {
            result.soCccd = standaloneCccdCandidate
        }

        // 2. Họ và tên (prefer accented Vietnamese line)
        for (idx, line) in lines.enumerated() {
            let folded = foldedLines[idx]
            guard folded.contains("ho va ten") || folded.contains("full name") else { continue }
            var inlineCandidate = stripLabelPrefix(
                line,
                foldedPatterns: ["ho va ten", "full name"]
            )
            inlineCandidate = normalizeSpaces(inlineCandidate.trimmingCharacters(in: CharacterSet(charactersIn: ":/.-– ")))
            if isLikelyPersonName(inlineCandidate) {
                result.hoTen = inlineCandidate
                break
            }
            if idx + 1 < lines.count {
                let nextLine = normalizeSpaces(lines[idx + 1])
                let nextFolded = foldedLines[idx + 1]
                if !isKnownFieldLabel(nextFolded) && !isMrzNoiseLine(nextFolded) && isLikelyPersonName(nextLine) {
                    result.hoTen = nextLine
                    break
                }
            }
        }

        // 3. Ngày sinh
        for (idx, line) in lines.enumerated() {
            let folded = foldedLines[idx]
            guard folded.contains("ngay sinh") || folded.contains("date of birth") else { continue }
            if let dateStr = extractUiDateFromString(line) {
                result.ngaySinh = dateStr
                break
            }
            if idx + 1 < lines.count,
               !foldedLines[idx + 1].contains("co gia tri"),
               !foldedLines[idx + 1].contains("ngay, thang"),
               let dateStr = extractUiDateFromString(lines[idx + 1]) {
                result.ngaySinh = dateStr
                break
            }
        }

        // 4. Giới tính (strictly avoid matching "Việt Nam")
        for (idx, line) in lines.enumerated() {
            let folded = foldedLines[idx]
            guard folded.contains("gioi tinh") || folded.contains("sex") else { continue }
            let segmentBeforeNationality: String = {
                if let range = folded.range(of: "quoc tich") ?? folded.range(of: "nationality") {
                    let prefixLen = folded.distance(from: folded.startIndex, to: range.lowerBound)
                    return String(folded.prefix(prefixLen))
                }
                return folded
            }()
            if let gender = extractGenderToken(fromFolded: segmentBeforeNationality) {
                result.gioiTinh = gender
                break
            }
            if idx + 1 < lines.count,
               let gender = extractGenderToken(fromFolded: foldedLines[idx + 1]) {
                result.gioiTinh = gender
                break
            }
        }

        // 5. Nơi thường trú (ưu tiên) / Quê quán (fallback)
        let stopMarkers = [
            "co gia tri", "date of expiry", "que quan", "place of origin",
            "noi thuong tru", "place of residence", "dac diem", "personal identification",
            "ngay, thang", "ngay thang nam", "date, month", "cuc truong", "director"
        ]
        func extractAddress(matchingMarkers: [String], patterns: [String]) -> String {
            for (idx, line) in lines.enumerated() {
                let folded = foldedLines[idx]
                guard matchingMarkers.contains(where: { folded.contains($0) }) else { continue }
                var segments: [String] = []
                let inlineVal = stripLabelPrefix(line, foldedPatterns: patterns)
                if isMeaningfulAddressSegment(inlineVal) {
                    segments.append(inlineVal)
                }
                for offset in 1...3 {
                    let nextIdx = idx + offset
                    guard nextIdx < lines.count else { break }
                    let nextLine = normalizeSpaces(lines[nextIdx])
                    let nextFolded = foldedLines[nextIdx]
                    if isMrzNoiseLine(nextFolded) || stopMarkers.contains(where: { nextFolded.contains($0) }) {
                        break
                    }
                    // Strip trailing label echo like "Có giá trị đến..." if mixed on the same horizontal row
                    let trimmedNext = trimTrailingExpiryText(nextLine)
                    if isMeaningfulAddressSegment(trimmedNext) {
                        segments.append(trimmedNext)
                    }
                    if nextLine.count != trimmedNext.count {
                        break
                    }
                }
                if !segments.isEmpty {
                    var joined = ""
                    for seg in segments {
                        if joined.isEmpty {
                            joined = seg
                        } else if joined.hasSuffix(",") || seg.hasPrefix(",") {
                            joined += " " + seg.trimmingCharacters(in: CharacterSet(charactersIn: " "))
                        } else {
                            joined += ", " + seg
                        }
                    }
                    return normalizeSpaces(joined)
                }
            }
            return ""
        }

        let residence = extractAddress(
            matchingMarkers: ["noi thuong tru", "place of residence"],
            patterns: ["noi thuong tru", "place of residence"]
        )
        if !residence.isEmpty {
            result.queQuan = residence
        } else {
            result.queQuan = extractAddress(
                matchingMarkers: ["que quan", "place of origin"],
                patterns: ["que quan", "place of origin"]
            )
        }

        // 6. Ngày cấp (Mặt sau: "Ngày, tháng, năm / Date, month, year" + dd/MM/yyyy)
        for (idx, line) in lines.enumerated() {
            let folded = foldedLines[idx]
            guard folded.contains("ngay, thang")
                || folded.contains("ngay thang nam")
                || folded.contains("date, month")
                || folded.contains("ngay cap") else {
                continue
            }
            if let dateStr = extractUiDateFromString(line) ?? extractVietnameseTextDateFromString(line) {
                result.ngayCap = dateStr
                break
            }
            let neighborIndices = [idx - 1, idx + 1, idx + 2]
            for nIdx in neighborIndices where nIdx >= 0 && nIdx < lines.count {
                let nFolded = foldedLines[nIdx]
                if nFolded.contains("ngay sinh")
                    || nFolded.contains("date of birth")
                    || nFolded.contains("co gia tri")
                    || nFolded.contains("date of expiry")
                    || isMrzNoiseLine(nFolded) {
                    continue
                }
                if let dateStr = extractUiDateFromString(lines[nIdx]) ?? extractVietnameseTextDateFromString(lines[nIdx]) {
                    result.ngayCap = dateStr
                    break
                }
            }
            if !result.ngayCap.isEmpty {
                break
            }
        }

        return result
    }

    private static func normalizeMrzLine(_ line: String) -> String {
        line.replacingOccurrences(of: "«", with: "<<")
            .replacingOccurrences(of: "‹", with: "<")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private static func extractLine1Candidate(from line: String) -> String? {
        if let range = line.range(of: "IDVNM") {
            return String(line[range.lowerBound...])
        }
        for prefix in ["1DVNM", "LDVNM", "IOVNM"] {
            if let range = line.range(of: prefix) {
                let suffix = String(line[range.lowerBound...].dropFirst(5))
                if suffix.count >= 22 {
                    return "IDVNM" + suffix
                }
            }
        }
        return nil
    }

    private static func sanitizeMrzDigits(_ input: String) -> String {
        var out = ""
        out.reserveCapacity(input.count)
        for ch in input.uppercased() {
            switch ch {
            case "0"..."9": out.append(ch)
            case "O", "Q", "D": out.append("0")
            case "I", "L", "|", "!": out.append("1")
            case "Z": out.append("2")
            case "S": out.append("5")
            case "B": out.append("8")
            default: break
            }
        }
        return out
    }

    private static func containsVietnameseDiacritics(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.value > 127 }
    }

    private static func foldVietnameseForComparison(_ text: String) -> String {
        text.replacingOccurrences(of: "đ", with: "d")
            .replacingOccurrences(of: "Đ", with: "D")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi_VN"))
    }

    private static func firstValidCccd12InString(_ text: String) -> String? {
        let pattern = #"(?<!\d)(\d{12})(?!\d)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            let digits = String(text[range])
            if DirectEntryContract.isValidCccd12(digits) {
                return digits
            }
        }
        let compactDigits = text.filter { $0.isNumber }
        if compactDigits.count == 12 && DirectEntryContract.isValidCccd12(compactDigits) {
            return compactDigits
        }
        return nil
    }

    private static func stripLabelPrefix(_ original: String, foldedPatterns: [String]) -> String {
        var working = normalizeSpaces(original)
        let folded = foldVietnameseForComparison(working)
        var cutEndOffset = 0
        for pattern in foldedPatterns {
            if let range = folded.range(of: pattern) {
                let offset = folded.distance(from: folded.startIndex, to: range.upperBound)
                if offset > cutEndOffset {
                    cutEndOffset = offset
                }
            }
        }
        if cutEndOffset > 0 && cutEndOffset <= working.count {
            let startIdx = working.index(working.startIndex, offsetBy: cutEndOffset)
            working = String(working[startIdx...])
        } else if let colonIdx = working.firstIndex(of: ":") {
            working = String(working[working.index(after: colonIdx)...])
        }
        return normalizeSpaces(working.trimmingCharacters(in: CharacterSet(charactersIn: ":/.-– ")))
    }

    private static func isLikelyPersonName(_ candidate: String) -> Bool {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4,
              !trimmed.contains(where: { $0.isNumber }),
              trimmed.contains(where: { $0.isLetter }) else {
            return false
        }
        return true
    }

    private static func extractUiDateFromString(_ text: String) -> String? {
        let pattern = #"(\d{1,2})\s*[/\-]\s*(\d{1,2})\s*[/\-]\s*((?:19|20|21)\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let dRange = Range(match.range(at: 1), in: text),
              let mRange = Range(match.range(at: 2), in: text),
              let yRange = Range(match.range(at: 3), in: text),
              let d = Int(text[dRange]),
              let m = Int(text[mRange]),
              let y = Int(text[yRange]),
              (1...31).contains(d), (1...12).contains(m), (1900...2100).contains(y) else {
            return nil
        }
        return String(format: "%02d/%02d/%04d", d, m, y)
    }

    private static func extractVietnameseTextDateFromString(_ text: String) -> String? {
        let folded = foldVietnameseForComparison(text)
        let pattern = #"ngay\s+(\d{1,2})\s+thang\s+(\d{1,2})\s+nam\s+((?:19|20|21)\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: folded, range: NSRange(folded.startIndex..., in: folded)),
              let dRange = Range(match.range(at: 1), in: folded),
              let mRange = Range(match.range(at: 2), in: folded),
              let yRange = Range(match.range(at: 3), in: folded),
              let d = Int(folded[dRange]),
              let m = Int(folded[mRange]),
              let y = Int(folded[yRange]),
              (1...31).contains(d), (1...12).contains(m), (1900...2100).contains(y) else {
            return nil
        }
        return String(format: "%02d/%02d/%04d", d, m, y)
    }

    private static func extractGenderToken(fromFolded folded: String) -> String? {
        let sanitized = folded
            .replacingOccurrences(of: "viet nam", with: " ")
            .replacingOccurrences(of: "vietnam", with: " ")
        let words = sanitized
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        for word in words {
            if word == "nu" || word == "female" {
                return "Nữ"
            }
            if word == "nam" || word == "male" {
                return "Nam"
            }
        }
        return nil
    }

    private static func isMeaningfulAddressSegment(_ text: String) -> Bool {
        let cleaned = text.trimmingCharacters(in: CharacterSet(charactersIn: ":/.-– "))
        guard cleaned.count >= 2 else { return false }
        let folded = foldVietnameseForComparison(cleaned)
        if folded == "can cuoc cong dan" || folded == "citizen identity card" || folded == "viet nam" {
            return false
        }
        return cleaned.contains(where: { $0.isLetter || $0.isNumber })
    }

    private static func trimTrailingExpiryText(_ text: String) -> String {
        let folded = foldVietnameseForComparison(text)
        for marker in ["co gia tri", "date of expiry"] {
            if let range = folded.range(of: marker) {
                let offset = folded.distance(from: folded.startIndex, to: range.lowerBound)
                if offset >= 0 && offset < text.count {
                    let cutIdx = text.index(text.startIndex, offsetBy: offset)
                    return normalizeSpaces(String(text[..<cutIdx]))
                }
            }
        }
        return normalizeSpaces(text)
    }

    public static func repairUtf8MojibakeIfNeeded(_ input: String) -> String {
        let hasMarker = mojibakeMarkers.contains { input.contains($0) }
        guard hasMarker else { return input }

        if let isoBytes = input.data(using: .isoLatin1),
           let utf8Str = String(data: isoBytes, encoding: .utf8),
           !utf8Str.contains("\u{FFFD}") {
            return utf8Str
        }
        if let winBytes = input.data(using: .windowsCP1252),
           let utf8Str = String(data: winBytes, encoding: .utf8),
           !utf8Str.contains("\u{FFFD}") {
            return utf8Str
        }
        return input
    }

    public static func normalizeDateToUi(_ raw: String) -> String {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return "" }

        let digits = clean.filter { $0.isNumber }
        if digits.count == 8 {
            let d = Int(digits.prefix(2)) ?? 0
            let m = Int(digits.dropFirst(2).prefix(2)) ?? 0
            let y = Int(digits.suffix(4)) ?? 0
            if (1...31).contains(d) && (1...12).contains(m) && (1900...2100).contains(y) {
                return String(format: "%02d/%02d/%04d", d, m, y)
            }
            let yFirst = Int(digits.prefix(4)) ?? 0
            let mFirst = Int(digits.dropFirst(4).prefix(2)) ?? 0
            let dFirst = Int(digits.suffix(2)) ?? 0
            if (1900...2100).contains(yFirst) && (1...12).contains(mFirst) && (1...31).contains(dFirst) {
                return String(format: "%02d/%02d/%04d", dFirst, mFirst, yFirst)
            }
        }

        let partsSlash = clean.split(separator: "/")
        if partsSlash.count == 3,
           let d = Int(partsSlash[0]),
           let m = Int(partsSlash[1]),
           let y = Int(partsSlash[2]),
           (1...31).contains(d), (1...12).contains(m), (1900...2100).contains(y) {
            return String(format: "%02d/%02d/%04d", d, m, y)
        }

        let partsDash = clean.split(separator: "-")
        if partsDash.count == 3,
           let y = Int(partsDash[0]),
           let m = Int(partsDash[1]),
           let d = Int(partsDash[2]),
           (1...31).contains(d), (1...12).contains(m), (1900...2100).contains(y) {
            return String(format: "%02d/%02d/%04d", d, m, y)
        }

        return clean
    }

    public static func normalizeGenderToUi(_ raw: String) -> String {
        let lower = normalizeSpaces(raw).lowercased()
        guard !lower.isEmpty else { return "" }
        if lower == "nam" || lower == "male" || lower == "m" {
            return "Nam"
        }
        if lower == "nữ" || lower == "nu" || lower == "female" || lower == "f" {
            return "Nữ"
        }
        if lower == "khác" || lower == "khac" || lower == "other" {
            return "Khác"
        }
        return raw
    }

    private static func normalizeSpaces(_ s: String) -> String {
        s.precomposedStringWithCanonicalMapping
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

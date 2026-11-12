# Mini BI — iOS App (`HRP BI`)

Ứng dụng iOS gốc (**SwiftUI**, iOS `16.0+`) của hệ thống nội bộ **HR Partner Mini BI**, tách độc lập hoàn toàn khỏi ứng dụng Android (`nobita6986/mini-bi-android`).

## Cấu trúc Thư mục

- `project.yml`: Cấu hình chuẩn **XcodeGen** sinh tự động `HRPBI.xcodeproj` (không cần commit file `.xcodeproj` sinh tự động).
- `HRPBI/`: Toàn bộ mã nguồn ứng dụng (`App`, `Data`, `UI`, `Assets.xcassets`, `Info.plist`).
- `HRPBTests/`: Bộ kiểm thử đơn vị & hợp đồng bảo mật (`XCTest`).
- `.github/workflows/ios-ci-release.yml`: Pipeline GitHub Actions độc lập trên `macos-latest` (Chế độ 1: Build + Simulator `HRPBTests` cho mọi PR/push `main`; Chế độ 2: Archive + ký số `.ipa` + đẩy thẳng lên **TestFlight** khi chạy `workflow_dispatch` hoặc gắn tag `V1.0.*`).
- `docs/IOS_TESTFLIGHT_GUIDE.md`: Hướng dẫn cấu hình Apple Developer Secrets & phát hành TestFlight.

## Chạy Kiểm tra tại Máy macOS / CI

```bash
# 1. Sinh Xcode project từ project.yml
brew install xcodegen
xcodegen generate

# 2. Chạy toàn bộ bộ kiểm thử HRPBTests trên iOS Simulator
xcodebuild test \
  -project HRPBI.xcodeproj \
  -scheme HRP-BI \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=""
```

## Quy ước Làm việc & CI

1. Mọi thay đổi thực hiện trên nhánh tính năng tạo từ `origin/main`, mở Pull Request về `main` và chờ job **`Mode 1 & 2: Build, Unit Test & Upload to TestFlight`** xanh 100% trước khi merge.
2. Khi phát hành bản TestFlight mới: tăng `CURRENT_PROJECT_VERSION` trong `project.yml` (hiện tại đang là `154`, bản tiếp theo từ `155` trở lên) để App Store Connect chấp nhận gói `.ipa`.

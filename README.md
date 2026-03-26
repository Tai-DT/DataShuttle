<div align="center">

# 🚀 DataShuttle

### Điều phối dữ liệu thông minh giữa SSD, ổ ngoài và Cloud

<img src="https://img.shields.io/badge/Platform-macOS_15+-blue?logo=apple&logoColor=white" />
<img src="https://img.shields.io/badge/Swift-5.0-orange?logo=swift&logoColor=white" />
<img src="https://img.shields.io/badge/SwiftUI-Observation-purple?logo=swift&logoColor=white" />
<img src="https://img.shields.io/badge/License-MIT-green" />

<br/>

*Tự động chuyển dữ liệu nặng sang ổ phụ, tạo symlink trong suốt, tiết kiệm SSD chính.*

</div>

---

## ✨ Tính năng

| Tính năng | Mô tả |
|-----------|-------|
| 🔄 **Shuttle** | Chuyển thư mục nặng từ SSD chính → ổ ngoài, tạo symlink tự động |
| ↩️ **Restore** | Đưa dữ liệu về lại SSD chính bất kỳ lúc nào |
| 📥 **Import** | Nhập dữ liệu từ ổ ngoài về máy chính |
| ☁️ **Cloud Manager** | Phát hiện iCloud/Google Drive, phân tích & dọn dung lượng |
| 🩺 **Health Check** | Quét và sửa symlink hỏng tự động |
| 📊 **Analytics** | Theo dõi dung lượng đã tiết kiệm theo thời gian |
| ⚡ **Auto Shuttle** | Tự động chạy khi cắm ổ (Sync Profiles) |
| 🔖 **Bookmarks** | Lối tắt cho thư mục hay dùng |
| 🔔 **Notifications** | Thông báo hệ thống cho mọi thao tác |
| 📱 **Menu Bar** | Widget trên thanh menu — xem nhanh, điều khiển nhanh |

## 📸 Screenshots

> *Coming soon — chạy app và chụp screenshots*

## 🏗️ Kiến trúc

```
DataShuttle/
├── Models/         → ShuttleItem, TransferJob, VolumeInfo, SyncProfile...
├── Services/       → FileShuttleService, CloudStorageManager, DiskAnalyzer, DriveMonitor...
├── ViewModels/     → ShuttleViewModel, DashboardViewModel
├── Views/          → Dashboard, Shuttle, Import, Cloud, HealthCheck, Analytics...
└── Utilities/      → Constants, Extensions
```

**Concurrency Pattern:**
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — tất cả types mặc định MainActor
- Heavy I/O → `Task.detached` + `nonisolated` methods
- Thread-safe `@Observable` + `Sendable` models

## ⚙️ Yêu cầu

- macOS 15.0+
- Xcode 16+
- Swift 5.0

## 🚀 Cài đặt

```bash
git clone https://github.com/Tai-DT/DataShuttle.git
cd DataShuttle
open DataShuttle.xcodeproj
```

Bấm **⌘R** để build & run.

## 📦 Cách sử dụng

### Shuttle (Chuyển ra ổ ngoài)
1. Mở tab **Shuttle** → chọn thư mục cần chuyển
2. Chọn ổ đích → bấm **Shuttle**
3. App sẽ: Copy → Verify → Xóa gốc → Tạo Symlink
4. Thư mục vẫn xuất hiện ở vị trí cũ nhờ symlink trong suốt ✨

### Restore (Đưa về SSD chính)
1. Mở tab **Shuttle** → chọn item đã shuttle
2. Bấm **Restore** → dữ liệu được copy ngược về

### Cloud Manager
1. Mở tab **Cloud** → app tự phát hiện iCloud, Google Drive
2. Xem phân tích dung lượng → xóa file/thư mục dư trực tiếp

### Auto Shuttle
1. Tạo **Sync Profile** → chọn thư mục + ổ đích
2. Bật **Auto Trigger** → khi cắm ổ, tự chạy shuttle

---

## 💖 Support & Donate

Nếu DataShuttle giúp ích cho bạn, hãy cân nhắc ủng hộ tác giả để mình tiếp tục phát triển các công cụ miễn phí! 🙏

### 🇻🇳 Chuyển khoản ngân hàng (VietQR)

<div align="center">

| Thông tin | Chi tiết |
|-----------|----------|
| **Tên** | DO TAI |
| **Số TK** | `9021843687798` |
| **Ngân hàng** | Timo Digital Bank (BVBank) |

<img src="docs/donate/vietqr_donate.jpg" alt="VietQR Donate" width="300"/>

*Quét mã QR bằng app ngân hàng bất kỳ*

</div>

### 🪙 Crypto (Binance Pay)

<div align="center">

<img src="docs/donate/binance_donate.jpg" alt="Binance Pay Donate" width="300"/>

*Quét bằng app Binance để gửi crypto*

| Thông tin | Chi tiết |
|-----------|----------|
| **Nickname** | Do Tai |
| **Platform** | Binance Pay |

</div>

### ⭐ Hoặc đơn giản là...

- ⭐ **Star** repo này trên GitHub
- 🐛 Báo bug hoặc đề xuất tính năng qua [Issues](../../issues)
- 🔀 Gửi Pull Request

---

## 📄 License

MIT License — xem [LICENSE](LICENSE) để biết thêm chi tiết.

---

<div align="center">

**Made with ❤️ by Do Tai**

*DataShuttle — Giữ SSD gọn, dữ liệu an toàn*

</div>

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case vietnamese = "vi"
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case portugueseBrazil = "pt-BR"
    case russian = "ru"
    case chineseSimplified = "zh-Hans"
    case japanese = "ja"
    case korean = "ko"
    case hindi = "hi"
    case arabic = "ar"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .vietnamese: return "Tiếng Việt"
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .portugueseBrazil: return "Português (Brasil)"
        case .russian: return "Русский"
        case .chineseSimplified: return "简体中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .hindi: return "हिन्दी"
        case .arabic: return "العربية"
        }
    }
}

enum L10n {
    static let languageStorageKey = "appLanguage"

    static func locale(for languageCode: String) -> Locale {
        let selected = AppLanguage(rawValue: languageCode) ?? .system
        switch selected {
        case .system:
            return .autoupdatingCurrent
        default:
            return Locale(identifier: selected.rawValue)
        }
    }

    static func tr(_ key: String, languageCode: String) -> String {
        let selected = AppLanguage(rawValue: languageCode) ?? .system
        let code = selected == .system
            ? Locale.autoupdatingCurrent.language.languageCode?.identifier ?? "en"
            : selected.rawValue

        if let exact = translations[code]?[key] {
            return exact
        }

        if code.contains("-") {
            let shortCode = String(code.prefix { $0 != "-" })
            if let fallback = translations[shortCode]?[key] {
                return fallback
            }
        }

        return key
    }

    static let translations: [String: [String: String]] = [
        "en": [
            "Tổng quan": "Dashboard",
            "Shuttle": "Shuttle",
            "Import": "Import",
            "Ghi nhớ": "Bookmarks",
            "Tác vụ nhóm": "Profiles",
            "Cloud": "Cloud",
            "Health Check": "Health Check",
            "Phân tích": "Analytics",
            "Cài đặt": "Settings",
            "Bắt đầu từ các luồng chính": "Start from the main flows",
            "Đẩy dữ liệu sang ổ phụ hoặc cloud": "Move data to external drives or cloud",
            "Đưa dữ liệu về lại máy chính": "Bring data back to the main machine",
            "Lối tắt cho thư mục hay dùng": "Shortcuts for frequently used folders",
            "Chạy theo nhóm thư mục": "Run folder groups in one go",
            "Phát hiện đích đồng bộ đám mây": "Detect cloud sync destinations",
            "Kiểm tra symlink và ổ đĩa": "Check symlinks and drive status",
            "Theo dõi hiệu quả lưu trữ": "Track storage efficiency",
            "Tùy chỉnh hành vi ứng dụng": "Customize app behavior",
            "Điều phối dữ liệu giữa SSD, ổ ngoài và cloud": "Coordinate data between SSD, external drives, and cloud",
            "CHÍNH": "MAIN",
            "CHUYỂN DỮ LIỆU": "TRANSFER",
            "LƯU TRỮ": "STORAGE",
            "HỆ THỐNG": "SYSTEM",
            "Luồng chính ưu tiên tốc độ thao tác": "Core workflow optimized for speed",
            "Đang quản lý": "Managed",
            "Đã tiết kiệm": "Saved",
            "Ổ kết nối": "Connected drives",
            "Ổ đĩa": "Drives",
            "Mở DataShuttle": "Open DataShuttle",
            "Thoát": "Quit",
            "Tùy chỉnh DataShuttle": "Customize DataShuttle",
            "Ngôn ngữ": "Language",
            "Chọn ngôn ngữ hiển thị cho ứng dụng": "Choose the display language for the app",
            "Ngôn ngữ sẽ được áp dụng ngay lập tức trên các màn hình đã hỗ trợ.": "Language changes are applied immediately on supported screens.",
            "Chung": "General",
            "Xác nhận trước khi chuyển": "Confirm before transfer",
            "Hiện hộp thoại xác nhận trước mỗi thao tác": "Show a confirmation dialog before each action",
            "Tự động làm mới ổ đĩa": "Auto refresh drives",
            "Tự động phát hiện ổ đĩa mới kết nối": "Automatically detect newly connected drives",
            "Hiện file ẩn": "Show hidden files",
            "Hiển thị các thư mục bắt đầu bằng dấu chấm (.)": "Show folders that start with a dot (.)",
            "An toàn": "Safety",
            "Tạo bản sao trước khi chuyển": "Create backup before transfer",
            "Đảm bảo an toàn dữ liệu khi di chuyển": "Protect data safety during transfer",
            "Về DataShuttle": "About DataShuttle",
            "Phiên bản": "Version",
            "DataShuttle giúp bạn tối ưu dung lượng ổ đĩa chính bằng cách di chuyển thư mục sang ổ phụ và tạo symlink để các ứng dụng vẫn hoạt động bình thường.": "DataShuttle helps optimize your main drive by moving folders to external storage and creating symlinks so apps keep working normally.",
            "⚡ Tận dụng hiệu năng SSD chính cho hệ thống": "⚡ Keep main SSD performance for system tasks",
            "💾 Lưu trữ dữ liệu lớn trên ổ phụ": "💾 Store large data on external drives",
            "🔗 Symlink giữ mọi thứ hoạt động bình thường": "🔗 Symlinks keep everything working as expected",
            "⚡ Auto Shuttle: %@": "⚡ Auto Shuttle: %@",
            "Ổ \"%@\" đã cắm — đang chạy profile tự động.": "Drive \"%@\" connected — running auto profile.",
            "✅ Auto Shuttle xong: %@": "✅ Auto Shuttle complete: %@",
            "%d thư mục: %@": "%d folders: %@",
            "Lỗi": "Error",
            "Thành công": "Success",
            "Đã xảy ra lỗi": "An error occurred",
            "Hoàn thành": "Completed",
            "Bắt đầu nhanh với shuttle, import và kiểm tra trạng thái lưu trữ.": "Start quickly with shuttle, import, and storage status checks.",
            "Trung tâm điều phối": "Control Center",
            "Bắt đầu nhanh": "Quick Start",
            "Luồng cốt lõi": "Core Workflow",
            "Đưa dữ liệu ra ổ phụ": "Move data to external storage",
            "Phân tích thư mục lớn và shuttle có kiểm soát.": "Analyze large folders and shuttle with control.",
            "Mở Shuttle": "Open Shuttle",
            "Nhập dữ liệu về máy": "Import data back",
            "Kéo dữ liệu từ ổ phụ về SSD và chọn giữ hay xoá nguồn.": "Bring data from external drives to SSD and choose whether to keep source.",
            "Mở Import": "Open Import",
            "Kiểm tra liên kết": "Check links",
            "Quét symlink hỏng, phát hiện ổ bị ngắt và sửa nhanh.": "Scan broken symlinks, detect disconnected drives, and fix quickly.",
            "Mở Health Check": "Open Health Check",
            "Dùng đích cloud": "Use cloud destinations",
            "Phát hiện thư mục sync local để shuttle trực tiếp vào cloud.": "Detect local sync folders to shuttle directly to cloud.",
            "Mở Cloud": "Open Cloud",
            "Đã chuyển": "Moved",
            "Tiết kiệm": "Saved",
            "dung lượng ổ chính": "main drive space",
            "Mở Phân tích": "Open Analytics",
            "đang kết nối": "connected",
            "Đã chuyển gần đây": "Recently moved",
            "thư mục": "folders",
            "Trống": "Free",
            "đã dùng": "used",
            "Luồng Import": "Import Flow",
            "Chọn ổ nguồn, chọn thư mục hoặc duyệt tay, rồi đưa dữ liệu về đúng vị trí trên máy chính.": "Choose source drive, choose folder or browse manually, then bring data back to the correct place on your main machine.",
            "Thiếu đích": "Missing destination",
            "Sẵn sàng import": "Ready to import",
            "Ổ nguồn": "Source drive",
            "Chưa chọn ổ phụ": "No external drive selected",
            "Thư mục import": "Import folder",
            "Chọn tay hoặc từ danh sách quét": "Choose manually or from scanned list",
            "Có thể chọn nhanh từ danh sách bên dưới": "You can quickly select from the list below",
            "Đích trên máy": "Destination on main machine",
            "Bước 1: Chọn ổ nguồn": "Step 1: Select source drive",
            "Bước 2: Chọn thư mục nguồn": "Step 2: Select source folder",
            "Bước 3: Chọn vị trí đích trên ổ chính": "Step 3: Select destination on main drive",
            "Bước 4: Tùy chọn import": "Step 4: Import options",
            "Bước 5: Chọn nhanh từ danh sách quét": "Step 5: Quick pick from scanned list",
            "Duyệt": "Browse",
            "Di chuyển ngay": "Move now",
            "Sao chép ngay": "Copy now",
            "Chọn thư mục từ ổ phụ hoặc nhấp \"Chuyển\" bên dưới": "Choose a folder from external drive or click \"Move\" below",
            "Xóa nguồn sau khi chuyển": "Delete source after transfer",
            "⚠️ File gốc trên ổ phụ sẽ bị XÓA sau khi copy xong (Di chuyển)": "⚠️ Original files on external drive will be DELETED after copy (Move)",
            "File gốc trên ổ phụ sẽ được GIỮ NGUYÊN (Sao chép)": "Original files on external drive will be KEPT (Copy)",
            "Danh sách này giúp xử lý nhanh nhiều thư mục trên ổ phụ mà không cần duyệt tay từng lần.": "This list helps process many folders on external drives quickly without manual browsing each time.",
            "Đang chuyển": "Transferring",
            "Health Check sẽ tự chạy khi app đã có symlink để kiểm tra.": "Health Check runs automatically once the app has symlinks to verify.",
            "Màn này sẽ tự kiểm tra ngay khi bạn mở tab Health Check.": "This screen checks automatically when you open the Health Check tab.",
            "Đang quét": "Scanning",
            "Đang quét...": "Scanning...",
            "Quét ngay": "Scan now",
            "Kết quả quét": "Scan results",
            "Lần quét": "Scanned",
            "Tổng symlink": "Total symlinks",
            "Hoạt động": "Healthy",
            "Hỏng": "Broken",
            "Ổ ngắt": "Disconnected drives",
            "Hoạt động bình thường": "Working normally",
            "Không có lỗi nào được phát hiện": "No issues detected",
            "Đã kiểm tra": "Checked",
            "symlink đang được DataShuttle quản lý.": "symlinks managed by DataShuttle.",
            "Đã sửa symlink cho": "Fixed symlink for",
            "thành công!": "successfully!",
            "Cloud Storage": "Cloud Storage",
            "Quản lý & dọn dẹp dịch vụ lưu trữ đám mây": "Manage and clean up cloud storage services",
            "Quét lại": "Rescan",
            "Trạng thái dịch vụ cloud": "Cloud service status",
            "Kiểm tra kết nối": "Connection check",
            "Đường dẫn dự kiến": "Expected path",
            "Lưu ý: app chỉ kiểm tra thư mục sync local, tiến trình đồng bộ và app desktop trên macOS; không đọc trạng thái server của nhà cung cấp.": "Note: the app checks only local sync folders, sync processes, and desktop apps on macOS; it does not read provider server status.",
            "Đăng nhập iCloud": "Sign in to iCloud",
            "Mở": "Open",
            "để Đăng nhập": "to sign in",
            "Cài ứng dụng": "Install",
            "Kiểm tra lại": "Check again",
            "Mở thư mục CloudStorage": "Open CloudStorage folder",
            "Không tìm thấy dịch vụ cloud": "No cloud service found",
            "Hãy cài đặt iCloud Drive, Google Drive, Dropbox hoặc OneDrive để sử dụng tính năng này": "Install iCloud Drive, Google Drive, Dropbox, or OneDrive to use this feature",
            "Cách hoạt động": "How it works",
            "Xóa vĩnh viễn?": "Delete permanently?",
            "Xóa ngay": "Delete now",
            "Hủy": "Cancel",
            "Thông báo": "Notification",
            "Lỗi xóa file": "Delete file error",
            "Đã xảy ra lỗi không xác định.": "An unknown error occurred.",
            "Không thể xóa một số file:": "Could not delete some files:",
            "Mục": "Item",
            "sẽ bị xóa vĩnh viễn khỏi Cloud.": "will be permanently deleted from Cloud.",
            "mục đã chọn sẽ bị xóa vĩnh viễn khỏi Cloud.": "selected items will be permanently deleted from Cloud.",
            "Đang quét dịch vụ cloud...": "Scanning cloud services...",
            "Ghi nhận": "Capture",
            "Thống kê dung lượng và hiệu quả": "Storage and efficiency statistics",
            "Thư mục đã chuyển": "Moved folders",
            "đang quản lý": "managed",
            "đã ghi nhận": "recorded",
            "Dung lượng theo ổ đĩa": "Capacity by drive",
            "Không có dữ liệu": "No data",
            "Biến động dung lượng": "Capacity trend",
            "Chưa đủ dữ liệu để vẽ biểu đồ (cần ít nhất 2 lần ghi nhận)": "Not enough data to draw chart (need at least 2 captures)",
            "Thư mục đã shuttle (theo dung lượng)": "Shuttled folders (by size)",
            "Tỷ lệ sử dụng": "Usage ratio",
            "Đã dùng": "Used",
            "Thư mục hay dùng — chuyển nhanh 1 chạm": "Frequently used folders — one-tap quick transfer",
            "Thêm": "Add",
            "Hay dùng nhất": "Most used",
            "Tất cả": "All",
            "mục": "items",
            "Chưa có ghi nhớ nào": "No bookmarks yet",
            "Thêm thư mục hay dùng để chuyển nhanh giữa các ổ đĩa": "Add frequently used folders for quick transfer between drives",
            "Thêm ghi nhớ đầu tiên": "Add first bookmark",
            "Sync Profiles": "Sync Profiles",
            "Nhóm thư mục — shuttle cả nhóm 1 click": "Folder groups — shuttle all with one click",
            "Tạo Profile": "Create Profile",
            "Chưa có profile nào": "No profiles yet",
            "Tạo profile để nhóm nhiều thư mục và shuttle tất cả cùng lúc": "Create profiles to group many folders and shuttle all at once",
            "Ví dụ:": "Examples:",
            "Profile": "Profile",
            "hoàn tất": "completed",
            "Bước 1: Chọn thư mục gốc": "Step 1: Choose root folder",
            "Bước 2: Chọn đích lưu": "Step 2: Choose destination",
            "Bước 3: Chọn thư mục cần shuttle": "Step 3: Choose folders to shuttle",
            "Luồng Shuttle": "Shuttle Flow",
            "Chọn thư mục gốc, chọn đích lưu, rồi shuttle từng thư mục con được đề xuất.": "Choose a root folder, choose destination, then shuttle suggested subfolders.",
            "Chưa sẵn sàng": "Not ready",
            "Sẵn sàng phân tích": "Ready to analyze",
            "Nguồn": "Source",
            "Chưa chọn thư mục gốc": "No root folder selected",
            "Đã chọn thư mục để phân tích": "Folder selected for analysis",
            "Đích lưu": "Destination",
            "Chưa chọn ổ hoặc cloud path": "No drive or cloud path selected",
            "Danh sách đề xuất": "Suggested list",
            "Chưa có thư mục con để shuttle": "No subfolders to shuttle",
            "mục sẵn sàng xử lý": "items ready",
            "DataShuttle sẽ phân tích các thư mục con cấp đầu để bạn chọn chính xác phần nào nên chuyển đi.": "DataShuttle analyzes first-level subfolders so you can choose exactly what to move.",
            "Chưa chọn thư mục": "No folder selected",
            "Gợi ý:": "Suggestions:",
            "Dùng ổ ngoài, ổ phụ, hoặc thư mục cloud (iCloud, Google Drive...) làm đích.": "Use external drives or cloud folders (iCloud, Google Drive...) as destination.",
            "Không tìm thấy ổ phụ hay cloud. Kết nối ổ ngoài hoặc cài cloud storage.": "No external drive or cloud found. Connect external storage or install cloud storage.",
            "Thư mục đích trên cloud": "Destination folder on cloud",
            "Thư mục đích trên ổ phụ": "Destination folder on external drive",
            "mặc định": "default",
            "Đặt lại về mặc định": "Reset to default",
            "Mỗi thao tác sẽ copy sang đích lưu rồi thay thư mục gốc bằng symlink, nên app cũ vẫn hoạt động như bình thường.": "Each action copies to destination then replaces original folder with a symlink, so existing apps keep working.",
            "Theo dõi tiến trình": "Track progress",
            "Chưa có thư mục nào": "No folders yet",
            "Chuyển thư mục sang ổ phụ để quản lý tại đây": "Move folders to external storage to manage them here",
            "Chưa có lịch sử": "No history yet",
            "Các thao tác chuyển đổi sẽ hiển thị tại đây": "Transfer actions will appear here",
            "Chuyển": "Move",
            "Chuyển thư mục": "Move folder",
            "Thư mục sẽ được copy sang ổ phụ và tạo symlink tại vị trí gốc. Các ứng dụng vẫn hoạt động bình thường.": "The folder will be copied to external storage and replaced by a symlink at original location. Apps continue working normally.",
            "Thả thư mục vào đây": "Drop folder here",
            "Đang khôi phục": "Restoring",
            "Hủy chuyển": "Cancel transfer",
            "Hiện trong Finder": "Reveal in Finder",
            "Đang sao chép file...": "Copying files..."
            ,"Dung lượng": "Capacity"
            ,"Di chuyển": "Move"
            ,"Sao chép": "Copy"
            ,"Thư mục sẽ được chuyển từ ổ phụ sang ổ chính. File gốc trên ổ phụ sẽ bị xóa.": "The folder will be moved from external drive to main drive. Original files on external drive will be deleted."
            ,"Thư mục sẽ được sao chép từ ổ phụ sang ổ chính. File gốc vẫn giữ nguyên.": "The folder will be copied from external drive to main drive. Original files remain unchanged."
            ,"ổ phụ sẵn sàng": "external drives ready"
            ,"thư mục đang quản lý": "managed folders"
            ,"Làm mới": "Refresh"
            ,"Chưa có đích lưu trữ ngoài máy": "No external storage destination yet"
            ,"Kết nối ổ ngoài hoặc dùng thư mục cloud để bắt đầu shuttle dữ liệu lớn khỏi SSD chính.": "Connect external storage or use cloud folders to start shuttling large data off your main SSD."
            ,"Hệ thống đã sẵn sàng để shuttle": "System is ready to shuttle"
            ,"Bạn đã có đích lưu trữ. Bước tiếp theo là chọn thư mục lớn như Downloads, Movies hoặc Library/Developer.": "You already have a destination. Next step: choose large folders like Downloads, Movies, or Library/Developer."
            ,"Luồng lưu trữ đang hoạt động ổn định": "Storage flow is running smoothly"
            ,"Bạn đang giải phóng": "You are freeing"
            ,"trên ổ chính. Hãy kiểm tra Health Check định kỳ để giữ symlink luôn lành.": "on your main drive. Run Health Check regularly to keep symlinks healthy."
            ,"Tổng": "Total"
            ,"Đường dẫn thư mục": "Folder path"
            ,"Ví dụ: Ảnh cá nhân": "Example: Personal Photos"
            ,"Hướng": "Direction"
            ,"Lưu": "Save"
            ,"Không tìm thấy ổ chứa đích. Hãy kiểm tra kết nối hoặc cập nhật ghi nhớ.": "Destination drive not found. Check connections or update bookmark."
            ,"Chưa có đích mặc định. Hãy chỉnh sửa ghi nhớ.": "No default destination yet. Please edit the bookmark."
            ,"Xóa ghi nhớ?": "Delete bookmark?"
            ,"Xóa": "Delete"
            ,"sẽ bị xóa. Dữ liệu gốc không bị ảnh hưởng.": "will be deleted. Original data is not affected."
            ,"Ví dụ: Developer": "Example: Developer"
            ,"Chọn thư mục để thêm vào profile": "Choose folders to add to profile"
            ,"Tên ổ đĩa, ví dụ: Backup": "Drive name, e.g. Backup"
            ,"Tạo": "Create"
            ,"Auto": "Auto"
            ,"Chạy": "Run"
            ,"Xóa profile?": "Delete profile?"
            ,"Chọn thư mục để chuyển sang ổ phụ": "Choose a folder to move to external storage"
            ,"Chọn thư mục từ ổ phụ để chuyển vào ổ chính": "Choose a folder from external drive to move to main drive"
            ,"Chọn vị trí đích trên ổ chính": "Choose destination on main drive"
            ,"Chọn vị trí đích trên ổ phụ": "Choose destination on external drive"
            ,"Vui lòng chọn ổ đích": "Please choose destination drive"
            ,"shuttle sang ổ phụ": "shuttle to external drive"
            ,"Vui lòng chọn thư mục đích trên ổ chính": "Please choose destination folder on main drive"
            ,"về ổ chính thành công!": "to main drive successfully!"
            ,"import về ổ chính": "import to main drive"
            ,"Đã khôi phục": "Restored"
            ,"khôi phục về ổ chính": "restore to main drive"
        ],
        "es": [
            "Tổng quan": "Panel",
            "Shuttle": "Transferir",
            "Import": "Importar",
            "Ghi nhớ": "Marcadores",
            "Tác vụ nhóm": "Perfiles",
            "Cloud": "Nube",
            "Health Check": "Diagnóstico",
            "Phân tích": "Análisis",
            "Cài đặt": "Ajustes",
            "Ngôn ngữ": "Idioma",
            "Chung": "General",
            "An toàn": "Seguridad",
            "Về DataShuttle": "Acerca de DataShuttle",
            "Mở DataShuttle": "Abrir DataShuttle",
            "Thoát": "Salir"
        ],
        "fr": [
            "Tổng quan": "Tableau de bord",
            "Shuttle": "Transfert",
            "Import": "Importer",
            "Ghi nhớ": "Signets",
            "Tác vụ nhóm": "Profils",
            "Cloud": "Cloud",
            "Health Check": "Diagnostic",
            "Phân tích": "Analytique",
            "Cài đặt": "Réglages",
            "Ngôn ngữ": "Langue",
            "Chung": "Général",
            "An toàn": "Sécurité",
            "Về DataShuttle": "À propos de DataShuttle",
            "Mở DataShuttle": "Ouvrir DataShuttle",
            "Thoát": "Quitter"
        ],
        "de": [
            "Tổng quan": "Übersicht",
            "Shuttle": "Verschieben",
            "Import": "Importieren",
            "Ghi nhớ": "Lesezeichen",
            "Tác vụ nhóm": "Profile",
            "Cloud": "Cloud",
            "Health Check": "Systemcheck",
            "Phân tích": "Analyse",
            "Cài đặt": "Einstellungen",
            "Ngôn ngữ": "Sprache",
            "Chung": "Allgemein",
            "An toàn": "Sicherheit",
            "Về DataShuttle": "Über DataShuttle",
            "Mở DataShuttle": "DataShuttle öffnen",
            "Thoát": "Beenden"
        ],
        "pt-BR": [
            "Tổng quan": "Painel",
            "Shuttle": "Transferir",
            "Import": "Importar",
            "Ghi nhớ": "Favoritos",
            "Tác vụ nhóm": "Perfis",
            "Cloud": "Nuvem",
            "Health Check": "Verificação",
            "Phân tích": "Análises",
            "Cài đặt": "Configurações",
            "Ngôn ngữ": "Idioma",
            "Chung": "Geral",
            "An toàn": "Segurança",
            "Về DataShuttle": "Sobre o DataShuttle",
            "Mở DataShuttle": "Abrir DataShuttle",
            "Thoát": "Sair"
        ],
        "ru": [
            "Tổng quan": "Обзор",
            "Shuttle": "Перенос",
            "Import": "Импорт",
            "Ghi nhớ": "Закладки",
            "Tác vụ nhóm": "Профили",
            "Cloud": "Облако",
            "Health Check": "Проверка",
            "Phân tích": "Аналитика",
            "Cài đặt": "Настройки",
            "Ngôn ngữ": "Язык",
            "Chung": "Общие",
            "An toàn": "Безопасность",
            "Về DataShuttle": "О DataShuttle",
            "Mở DataShuttle": "Открыть DataShuttle",
            "Thoát": "Выход"
        ],
        "zh-Hans": [
            "Tổng quan": "概览",
            "Shuttle": "迁移",
            "Import": "导入",
            "Ghi nhớ": "书签",
            "Tác vụ nhóm": "配置组",
            "Cloud": "云",
            "Health Check": "健康检查",
            "Phân tích": "分析",
            "Cài đặt": "设置",
            "Ngôn ngữ": "语言",
            "Chung": "常规",
            "An toàn": "安全",
            "Về DataShuttle": "关于 DataShuttle",
            "Mở DataShuttle": "打开 DataShuttle",
            "Thoát": "退出"
        ],
        "ja": [
            "Tổng quan": "ダッシュボード",
            "Shuttle": "転送",
            "Import": "インポート",
            "Ghi nhớ": "ブックマーク",
            "Tác vụ nhóm": "プロファイル",
            "Cloud": "クラウド",
            "Health Check": "ヘルスチェック",
            "Phân tích": "分析",
            "Cài đặt": "設定",
            "Ngôn ngữ": "言語",
            "Chung": "一般",
            "An toàn": "安全",
            "Về DataShuttle": "DataShuttle について",
            "Mở DataShuttle": "DataShuttle を開く",
            "Thoát": "終了"
        ],
        "ko": [
            "Tổng quan": "대시보드",
            "Shuttle": "전송",
            "Import": "가져오기",
            "Ghi nhớ": "북마크",
            "Tác vụ nhóm": "프로필",
            "Cloud": "클라우드",
            "Health Check": "상태 점검",
            "Phân tích": "분석",
            "Cài đặt": "설정",
            "Ngôn ngữ": "언어",
            "Chung": "일반",
            "An toàn": "안전",
            "Về DataShuttle": "DataShuttle 정보",
            "Mở DataShuttle": "DataShuttle 열기",
            "Thoát": "종료"
        ],
        "hi": [
            "Tổng quan": "डैशबोर्ड",
            "Shuttle": "स्थानांतरण",
            "Import": "इंपोर्ट",
            "Ghi nhớ": "बुकमार्क",
            "Tác vụ nhóm": "प्रोफाइल",
            "Cloud": "क्लाउड",
            "Health Check": "हेल्थ चेक",
            "Phân tích": "विश्लेषण",
            "Cài đặt": "सेटिंग्स",
            "Ngôn ngữ": "भाषा",
            "Chung": "सामान्य",
            "An toàn": "सुरक्षा",
            "Về DataShuttle": "DataShuttle के बारे में",
            "Mở DataShuttle": "DataShuttle खोलें",
            "Thoát": "बंद करें"
        ],
        "ar": [
            "Tổng quan": "لوحة التحكم",
            "Shuttle": "نقل",
            "Import": "استيراد",
            "Ghi nhớ": "إشارات مرجعية",
            "Tác vụ nhóm": "ملفات تعريف",
            "Cloud": "السحابة",
            "Health Check": "فحص الصحة",
            "Phân tích": "تحليلات",
            "Cài đặt": "الإعدادات",
            "Ngôn ngữ": "اللغة",
            "Chung": "عام",
            "An toàn": "الأمان",
            "Về DataShuttle": "حول DataShuttle",
            "Mở DataShuttle": "فتح DataShuttle",
            "Thoát": "إنهاء"
        ]
    ]
}
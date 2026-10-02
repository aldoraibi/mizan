import AppKit
import MizanCore
import SwiftUI
import UserNotifications

/// التحقق من التحديثات — الاتصال الوحيد بالإنترنت في ميزان.
/// يطلب صفحة آخر إصدار العامة من GitHub فقط: لا يرسل أي بيانات عنك ولا عن استخدامك، ولا يحمّل شيئاً وحده.
/// إن وُجد إصدار أحدث يظهر تنبيه، والتنزيل بيدك من صفحة التحميل.
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()
    static let api = URL(string: "https://api.github.com/repos/aldoraibi/mizan/releases/latest")!
    static let page = URL(string: "https://aldoraibi.github.io/mizan/")!

    enum State: Equatable { case idle, checking, upToDate, available(String), failed }
    @Published var state: State = .idle
    @Published var lastCheck: Date?
    private var timer: Timer?

    static var current: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0" }
    var enabled: Bool { UserDefaults.standard.object(forKey: "autoUpdateCheck") as? Bool ?? true }
    var available: String? { if case .available(let v) = state { v } else { nil } }

    /// فحص بعد التشغيل بدقيقة، ثم مرة كل يوم — إن كان الخيار مفعّلاً.
    func start() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            guard let self, self.enabled else { return }
            self.check()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 24 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in if self?.enabled == true { self?.check() } }
        }
    }

    func check() {
        guard state != .checking else { return }
        state = .checking
        var req = URLRequest(url: Self.api, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let session = URLSession(configuration: .ephemeral)   // بلا ملفات تعريف ارتباط ولا ذاكرة مؤقتة
        session.dataTask(with: req) { data, resp, _ in
            var result: State = .failed
            if (resp as? HTTPURLResponse)?.statusCode == 200, let data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tag = json["tag_name"] as? String {
                let v = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                result = Version.isNewer(v, than: Updater.current) ? .available(v) : .upToDate
            }
            Task { @MainActor in
                self.state = result
                self.lastCheck = Date()
                if case .available(let v) = result { self.notifyOnce(v) }
            }
        }.resume()
    }

    func openDownload() { NSWorkspace.shared.open(Self.page) }

    private func notifyOnce(_ v: String) {
        let key = "update_notified_" + v
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        let c = UNMutableNotificationContent()
        c.title = tr("تحديث جديد لميزان", "Mizan update available")
        c.body = tr("الإصدار \(v) متاح. افتح ميزان لتنزيله.", "Version \(v) is available. Open Mizan to download it.")
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "update", content: c, trigger: nil))
    }
}

/// شريط صغير في القائمة حين يتوفر تحديث.
struct UpdateBanner: View {
    @Environment(\.palette) private var pal
    @ObservedObject var updater = Updater.shared
    var body: some View {
        if let v = updater.available {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill").font(.system(size: 16)).foregroundStyle(Color.mizanOn)
                VStack(alignment: .leading, spacing: 0) {
                    Text(tr("تحديث جديد متاح", "Update available")).font(.mz(12.5, .bold))
                    Text(rtlIsolated(tr("الإصدار \(v) · لديك \(Updater.current)", "Version \(v) · you have \(Updater.current)")))
                        .font(.mz(10.5)).foregroundStyle(pal.muted)
                }
                Spacer()
                Button(tr("تنزيل", "Download")) { updater.openDownload() }.buttonStyle(QuietButton(primary: true))
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.mizanOn.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.mizanOn.opacity(0.28), lineWidth: 0.8))
        }
    }
}

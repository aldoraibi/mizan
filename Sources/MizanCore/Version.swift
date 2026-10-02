import Foundation

/// مقارنة أرقام الإصدارات مثل «1.1» و «v1.0.2».
public enum Version {
    public static func parts(_ s: String) -> [Int] {
        s.trimmingCharacters(in: CharacterSet(charactersIn: "vV ")).split(separator: ".").map { Int($0) ?? 0 }
    }
    /// هل `remote` أحدث من `local`؟
    public static func isNewer(_ remote: String, than local: String) -> Bool {
        let a = parts(remote), b = parts(local)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}

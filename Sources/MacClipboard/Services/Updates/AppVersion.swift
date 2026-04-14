import Foundation

struct AppVersion: Comparable, CustomStringConvertible, Equatable {
    let components: [Int]
    let rawValue: String

    init?(_ rawValue: String) {
        let normalized =
            rawValue
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "v", with: "", options: [.anchored, .caseInsensitive])

        guard normalized.isEmpty == false else {
            return nil
        }

        let parts = normalized.split(separator: ".").map(String.init)
        guard parts.isEmpty == false else {
            return nil
        }

        let numericParts = parts.compactMap(Int.init)
        guard numericParts.count == parts.count else {
            return nil
        }

        self.rawValue = normalized
        components = numericParts
    }

    var description: String {
        rawValue
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let maxCount = max(lhs.components.count, rhs.components.count)

        for index in 0 ..< maxCount {
            let lhsValue = lhs.components.indices.contains(index) ? lhs.components[index] : 0
            let rhsValue = rhs.components.indices.contains(index) ? rhs.components[index] : 0

            guard lhsValue != rhsValue else {
                continue
            }

            return lhsValue < rhsValue
        }

        return false
    }
}

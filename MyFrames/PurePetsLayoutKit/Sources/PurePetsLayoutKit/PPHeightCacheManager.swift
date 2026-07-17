import UIKit

/// Compatibility implementation for the legacy public cache API.
/// The new layout does not depend on persisted index-path heights; this class exists so old callers do not break.
@objc(PPHeightCacheManager)
@objcMembers
public final class PPHeightCacheManager: NSObject {
    private static let baseKey = "PPHeightCacheDict"
    private static let instance = PPHeightCacheManager()

    private let lock = NSLock()
    private var caches: [String: [String: NSNumber]] = [:]

    public var heightCache: NSMutableDictionary {
        get {
            lock.pp_withLock {
                let result = NSMutableDictionary()
                for (key, value) in caches {
                    result[key] = NSMutableDictionary(dictionary: value)
                }
                return result
            }
        }
        set {
            var replacement: [String: [String: NSNumber]] = [:]
            for case let key as String in newValue.allKeys {
                guard let dictionary = newValue[key] as? NSDictionary else { continue }
                var values: [String: NSNumber] = [:]
                for case let itemKey as String in dictionary.allKeys {
                    if let number = dictionary[itemKey] as? NSNumber {
                        values[itemKey] = number
                    }
                }
                replacement[key] = values
            }
            lock.pp_withLock { caches = replacement }
        }
    }

    @objc(sharedManager)
    public class func sharedManager() -> PPHeightCacheManager {
        instance
    }

    @objc(loadCacheForKey:)
    public func loadCache(forKey cacheKey: String) {
        let stored = UserDefaults.standard.dictionary(forKey: fullKey(for: cacheKey)) ?? [:]
        let numbers = stored.reduce(into: [String: NSNumber]()) { result, entry in
            if let number = entry.value as? NSNumber { result[entry.key] = number }
        }
        lock.pp_withLock { caches[cacheKey] = numbers }
    }

    @objc(saveCacheForKey:)
    public func saveCache(forKey cacheKey: String) {
        let snapshot = lock.pp_withLock { caches[cacheKey] ?? [:] }
        UserDefaults.standard.set(snapshot, forKey: fullKey(for: cacheKey))
    }

    @objc(clearCacheForKey:)
    public func clearCache(forKey cacheKey: String) {
        lock.pp_withLock { caches.removeValue(forKey: cacheKey) }
        UserDefaults.standard.removeObject(forKey: fullKey(for: cacheKey))
    }

    @objc(heightForIndexPath:key:)
    public func height(for indexPath: IndexPath, key cacheKey: String) -> NSNumber? {
        lock.pp_withLock { caches[cacheKey]?[indexKey(for: indexPath)] }
    }

    @objc(setHeight:forIndexPath:key:)
    public func setHeight(_ height: CGFloat, for indexPath: IndexPath, key cacheKey: String) {
        guard height.isFinite, height > 0 else { return }
        lock.pp_withLock {
            var cache = caches[cacheKey] ?? [:]
            cache[indexKey(for: indexPath)] = NSNumber(value: Double(height))
            caches[cacheKey] = cache
        }
    }

    private func fullKey(for key: String) -> String {
        "\(Self.baseKey)_\(key)"
    }

    private func indexKey(for indexPath: IndexPath) -> String {
        "\(indexPath.section)-\(indexPath.item)"
    }
}

private extension NSLock {
    func pp_withLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}

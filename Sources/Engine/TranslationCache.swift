import Foundation

/// Thread-safe translation cache with LRU eviction and text normalization
class TranslationCache {
    private let queue = DispatchQueue(label: "translation.cache")
    private var cache: [String: String] = [:]
    private var order: [String] = []  // Track insertion order for LRU
    private let maxSize: Int
    
    /// Codable structure for persisting cache
    private struct CacheData: Codable {
        let cache: [String: String]
        let order: [String]
        let version: Int
    }
    
    init(maxSize: Int) {
        self.maxSize = maxSize
    }
    
    /// Get translation from cache
    func get(_ text: String) -> String? {
        let normalizedKey = normalize(text)
        return queue.sync { cache[normalizedKey] }
    }
    
    /// Store translation in cache
    func set(_ text: String, translation: String) {
        let normalizedKey = normalize(text)
        queue.sync {
            // If key already exists, just update value
            if cache[normalizedKey] != nil {
                cache[normalizedKey] = translation
                return
            }
            
            // Add new entry
            cache[normalizedKey] = translation
            order.append(normalizedKey)
            
            // Evict old entries if over limit
            while order.count > maxSize {
                let oldKey = order.removeFirst()
                cache.removeValue(forKey: oldKey)
            }
        }
    }
    
    /// Clear all cached translations (memory only)
    func clear() {
        queue.sync {
            cache.removeAll()
            order.removeAll()
        }
    }
    
    /// Delete cache file from disk
    func deleteFile(at path: String) -> Bool {
        do {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(at: url)
                log.info("Cache file deleted: \(path)", category: .cache)
                return true
            } else {
                log.info("No cache file to delete at \(path)", category: .cache)
                return false
            }
        } catch {
            log.error("Failed to delete cache file: \(error)", category: .cache)
            return false
        }
    }
    
    /// Get current cache size
    var size: Int {
        queue.sync { cache.count }
    }
    
    /// Save cache to file
    func save(to path: String) -> Bool {
        return queue.sync {
            let cacheData = CacheData(
                cache: cache,
                order: order,
                version: 1
            )
            
            do {
                let url = URL(fileURLWithPath: path)
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(cacheData)
                
                // Create directory if needed
                let directory = url.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                
                try data.write(to: url)
                log.info("Cache saved: \(cache.count) entries to \(path)", category: .cache)
                return true
            } catch {
                log.error("Failed to save cache: \(error)", category: .cache)
                return false
            }
        }
    }
    
    /// Load cache from file
    func load(from path: String) -> Bool {
        return queue.sync {
            do {
                let url = URL(fileURLWithPath: path)
                guard FileManager.default.fileExists(atPath: path) else {
                    log.info("No cache file found at \(path)", category: .cache)
                    return false
                }
                
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let cacheData = try decoder.decode(CacheData.self, from: data)
                
                // Restore cache
                cache = cacheData.cache
                order = cacheData.order
                
                // Trim to max size if needed
                while order.count > maxSize {
                    let oldKey = order.removeFirst()
                    cache.removeValue(forKey: oldKey)
                }
                
                log.info("Cache loaded: \(cache.count) entries from \(path)", category: .cache)
                return true
            } catch {
                log.error("Failed to load cache: \(error)", category: .cache)
                return false
            }
        }
    }
    
    /// Normalize text for consistent caching (handles OCR variations)
    private func normalize(_ text: String) -> String {
        var normalized = text
            .lowercased()
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Normalize common OCR mistakes
        normalized = normalized
            .replacingOccurrences(of: "histore", with: "histoire")
            .replacingOccurrences(of: "tkes", with: "très")
            .replacingOccurrences(of: "untkes", with: "un très")
            .replacingOccurrences(of: "cour!", with: "coeur!")
        
        // Remove extra punctuation spaces
        normalized = normalized
            .replacingOccurrences(of: " !", with: "!")
            .replacingOccurrences(of: " ?", with: "?")
            .replacingOccurrences(of: " .", with: ".")
        
        return normalized
    }
}

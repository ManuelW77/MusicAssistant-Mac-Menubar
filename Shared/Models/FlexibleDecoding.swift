import Foundation

// Manche Provider-Integrationen liefern für Felder, die der Server selbst als
// int/float deklariert, gelegentlich einen anderen JSON-Typ (z.B. duration
// als Float statt Int, year als String statt Int — beides real gegen den
// echten Server beobachtet, siehe Track.swift/Album.swift). Python erzwingt
// seine Typannotationen zur Laufzeit nicht, daher robust statt strikt
// decodieren, um nicht bei jedem neuen Fall erneut zu crashen.
extension KeyedDecodingContainer {
    func decodeFlexibleIntIfPresent(forKey key: Key) throws -> Int? {
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return intValue
        }
        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(doubleValue)
        }
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return Int(stringValue) ?? Int(stringValue.prefix(while: \.isNumber))
        }
        return nil
    }

    func decodeFlexibleDoubleIfPresent(forKey key: Key) throws -> Double? {
        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return doubleValue
        }
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return Double(stringValue)
        }
        return nil
    }
}

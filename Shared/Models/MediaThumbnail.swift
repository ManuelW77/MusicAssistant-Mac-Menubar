import Foundation

// Feldnamen aus der Music-Assistant-Server-Quellcode-Recherche
// (music_assistant_models/media_items/metadata.py, MediaItemImage), aber
// noch nicht gegen den echten Server verifiziert (siehe Tools/VerifyConnection).
//
// Server liefert kein fertiges Bild-URL, sondern eine proxyId, die clientseitig
// zu `/imageproxy/<proxyId>` aufgelöst werden muss (über MassEndpoint.resolveImageURL).
// Zwei Formen kommen vor, je nachdem ob ein Suchergebnis ein volles MediaItem
// oder ein schlankes ItemMapping ist: volle Items tragen ihre Bilder unter
// `metadata.images[]` (dieser Typ), ItemMapping dagegen direkt unter einem
// Top-Level-`image`-Feld vom Typ MediaImageRef — beide werden in den Modellen
// unterstützt, die diese Datei nutzen.

public struct MediaImageRef: Codable, Equatable, Sendable {
    public let type: String?
    public let proxyId: String?

    public init(type: String?, proxyId: String?) {
        self.type = type
        self.proxyId = proxyId
    }
}

public struct MediaThumbnail: Codable, Equatable, Sendable {
    public let images: [MediaImageRef]?

    public init(images: [MediaImageRef]?) {
        self.images = images
    }

    public var proxyId: String? {
        (images?.first { $0.type == "thumb" } ?? images?.first)?.proxyId
    }
}

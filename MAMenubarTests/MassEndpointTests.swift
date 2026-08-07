import Foundation
import Testing
@testable import MAMenubarLib

@Suite("MassEndpoint")
struct MassEndpointTests {
    private let serverBaseURL = URL(string: "https://music.fire-devils.org")!

    @Test("ersetzt eine private LAN-Host-Bild-URL durch die öffentliche Server-Basis-URL")
    func rewritesPrivateHost() {
        let raw = "http://192.168.1.5:8095/imageproxy/abc123?size=512&fmt=jpg"
        let resolved = MassEndpoint.resolveImageURL(raw, serverBaseURL: serverBaseURL)
        #expect(resolved?.absoluteString == "https://music.fire-devils.org/imageproxy/abc123?size=512&fmt=jpg")
    }

    @Test("lässt externe Provider-URLs unverändert")
    func keepsExternalHost() {
        let raw = "https://i.scdn.co/image/abcdef"
        let resolved = MassEndpoint.resolveImageURL(raw, serverBaseURL: serverBaseURL)
        #expect(resolved?.absoluteString == raw)
    }

    @Test("löst relative Pfade gegen die Server-Basis-URL auf")
    func resolvesRelativePath() {
        let resolved = MassEndpoint.resolveImageURL("/imageproxy/xyz", serverBaseURL: serverBaseURL)
        #expect(resolved?.absoluteString == "https://music.fire-devils.org/imageproxy/xyz")
    }

    @Test("gibt nil für leere/fehlende Bild-URL zurück")
    func handlesNil() {
        #expect(MassEndpoint.resolveImageURL(nil, serverBaseURL: serverBaseURL) == nil)
        #expect(MassEndpoint.resolveImageURL("", serverBaseURL: serverBaseURL) == nil)
    }
}

import Foundation
import Testing
@testable import MAMenubarLib

@Suite("Search")
struct SearchTests {
    @Test("encoded SearchArgs als search_query/media_types")
    func encodesSearchArgsSnakeCase() throws {
        let args = SearchArgs(searchQuery: "Test")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(args)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["search_query"] as? String == "Test")
        #expect(json?["media_types"] as? [String] == ["track", "album", "playlist", "artist"])
    }

    @Test("decodiert Track als volles MediaItem mit metadata.images")
    func decodesTrackAsFullMediaItem() throws {
        let json = """
        {
            "item_id": "1", "provider": "builtin", "name": "Ein Titel",
            "uri": "library://track/1", "duration": 180,
            "artists": [{"name": "Ein Interpret"}],
            "album": {"name": "Ein Album"},
            "metadata": {"images": [{"type": "thumb", "proxy_id": "abc"}]}
        }
        """
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        let track = try value.decode(Track.self)

        #expect(track.itemId == "1")
        #expect(track.duration == 180)
        #expect(track.artistNames == "Ein Interpret")
        #expect(track.albumName == "Ein Album")
        #expect(track.imageProxyId == "abc")
    }

    @Test("decodiert Track.albumRef/primaryArtistRef aus verschachtelten item_id/provider")
    func decodesTrackNavigationRefs() throws {
        let json = """
        {
            "item_id": "1", "provider": "builtin", "name": "Ein Titel",
            "uri": "library://track/1", "duration": 180,
            "artists": [{"name": "Ein Interpret", "item_id": "5", "provider": "builtin"}],
            "album": {"name": "Ein Album", "item_id": "6", "provider": "builtin"}
        }
        """
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        let track = try value.decode(Track.self)

        #expect(track.albumRef == MediaItemRef(itemId: "6", provider: "builtin", name: "Ein Album"))
        #expect(track.primaryArtistRef == MediaItemRef(itemId: "5", provider: "builtin", name: "Ein Interpret"))
    }

    @Test("Track.primaryArtistRef.uri wird für den Play-Button in ArtistDetailView mitgegeben")
    func decodesTrackNavigationRefUri() throws {
        let json = """
        {
            "item_id": "1", "provider": "builtin", "name": "Ein Titel",
            "uri": "library://track/1",
            "artists": [{"name": "Ein Interpret", "item_id": "5", "provider": "builtin", "uri": "library://artist/5"}]
        }
        """
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        let track = try value.decode(Track.self)

        #expect(track.primaryArtistRef?.uri == "library://artist/5")
    }

    @Test("Track.albumRef/primaryArtistRef sind nil ohne verschachtelte item_id/provider")
    func decodesTrackNavigationRefsMissing() throws {
        let json = """
        {
            "item_id": "2", "provider": "spotify", "name": "Anderer Titel",
            "uri": "spotify://track/2",
            "artists": [{"name": "Ein Interpret"}],
            "album": {"name": "Ein Album"}
        }
        """
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        let track = try value.decode(Track.self)

        #expect(track.albumRef == nil)
        #expect(track.primaryArtistRef == nil)
    }

    @Test("decodiert Track als schlankes ItemMapping mit direktem image-Feld")
    func decodesTrackAsItemMapping() throws {
        let json = """
        {
            "item_id": "2", "provider": "spotify", "name": "Anderer Titel",
            "uri": "spotify://track/2",
            "image": {"type": "thumb", "proxy_id": "xyz"}
        }
        """
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        let track = try value.decode(Track.self)

        #expect(track.duration == nil)
        #expect(track.artistNames == "")
        #expect(track.imageProxyId == "xyz")
    }

    @Test("decodiert Album als volles MediaItem")
    func decodesAlbumAsFullMediaItem() throws {
        let json = """
        {
            "item_id": "10", "provider": "builtin", "name": "Ein Album",
            "uri": "library://album/10", "year": 2020,
            "artists": [{"name": "Ein Interpret"}],
            "metadata": {"images": [{"type": "thumb", "proxy_id": "abc"}]}
        }
        """
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        let album = try value.decode(Album.self)

        #expect(album.year == 2020)
        #expect(album.artistNames == "Ein Interpret")
        #expect(album.imageProxyId == "abc")
    }

    @Test("decodiert Album als schlankes ItemMapping")
    func decodesAlbumAsItemMapping() throws {
        let json = """
        {
            "item_id": "11", "provider": "spotify", "name": "Anderes Album",
            "uri": "spotify://album/11",
            "image": {"type": "thumb", "proxy_id": "xyz"}
        }
        """
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        let album = try value.decode(Album.self)

        #expect(album.year == nil)
        #expect(album.imageProxyId == "xyz")
    }

    @Test("decodiert Artist als volles MediaItem")
    func decodesArtistAsFullMediaItem() throws {
        let json = """
        {
            "item_id": "20", "provider": "builtin", "name": "Ein Interpret",
            "uri": "library://artist/20",
            "metadata": {"images": [{"type": "thumb", "proxy_id": "abc"}]}
        }
        """
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        let artist = try value.decode(Artist.self)

        #expect(artist.name == "Ein Interpret")
        #expect(artist.imageProxyId == "abc")
    }

    @Test("decodiert Artist als schlankes ItemMapping")
    func decodesArtistAsItemMapping() throws {
        let json = """
        {
            "item_id": "21", "provider": "spotify", "name": "Anderer Interpret",
            "uri": "spotify://artist/21",
            "image": {"type": "thumb", "proxy_id": "xyz"}
        }
        """
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        let artist = try value.decode(Artist.self)

        #expect(artist.imageProxyId == "xyz")
    }

    @Test("decodiert Playlist mit metadata.images")
    func decodesPlaylistWithImage() throws {
        let json = """
        {
            "item_id": "30", "provider": "builtin", "name": "Eine Playlist",
            "uri": "library://playlist/30",
            "metadata": {"images": [{"type": "thumb", "proxy_id": "abc"}]}
        }
        """
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        let playlist = try value.decode(Playlist.self)

        #expect(playlist.imageProxyId == "abc")
    }

    @Test("decodiert Playlist als schlankes ItemMapping mit direktem image-Feld")
    func decodesPlaylistAsItemMapping() throws {
        let json = """
        {
            "item_id": "31", "provider": "spotify", "name": "Andere Playlist",
            "uri": "spotify://playlist/31",
            "image": {"type": "thumb", "proxy_id": "xyz"}
        }
        """
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        let playlist = try value.decode(Playlist.self)

        #expect(playlist.imageProxyId == "xyz")
    }
}

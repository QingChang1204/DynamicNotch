import Foundation
import Cocoa

class MediaInfoManager {
    static let shared = MediaInfoManager()

    private var mediaChangeNotification: NSObjectProtocol?

    private init() {
        print("Initializing MediaInfoManager")
        
        // Register for now playing notifications
        MRMediaRemoteRegisterForNowPlayingNotifications(DispatchQueue.main)
        print("Registered for now playing notifications")

        // Register for media change notifications
        mediaChangeNotification = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil,
            queue: nil
        ) { [weak self] notification in
            print("Notification received: \(notification)")
            self?.fetchNowPlayingInfo()
        }
        
        // Fetch initial now playing info
        fetchNowPlayingInfo()
    }

    deinit {
        print("Deinitializing MediaInfoManager")
        
        if let notification = mediaChangeNotification {
            NotificationCenter.default.removeObserver(notification)
            print("Removed media change notification observer")
        }
        
        MRMediaRemoteUnregisterForNowPlayingNotifications()
        print("Unregistered for now playing notifications")
    }

    private func fetchNowPlayingInfo() {
        MRMediaRemoteGetNowPlayingInfo(DispatchQueue.main) { info in
            guard let info = info as? [String: Any] else {
                print("Failed to get now playing info")
                return
            }

            let artist = info["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? "Unknown Artist"
            let title = info["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? "Unknown Title"
            let album = info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String ?? "Unknown Album"
            
            var artworkImage: NSImage? = nil

            if let artworkData = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                artworkImage = NSImage(data: artworkData)
            }

            // Handle the fetched information (update UI, log, etc.)
            print("Now Playing: \(title) by \(artist) · \(album)")
            if let artwork = artworkImage {
                print("Artwork image available")
                // Do something with the artwork
            } else {
                print("No artwork available")
            }
        }
    }
}

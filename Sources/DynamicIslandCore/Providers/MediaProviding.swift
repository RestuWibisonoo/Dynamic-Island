import Foundation
import Combine

public struct MediaTrack: Equatable, Sendable {
    public let title: String
    public let artist: String
    public let album: String
    public let duration: TimeInterval
    
    public init(title: String, artist: String, album: String, duration: TimeInterval) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
    }
}

public enum MediaSourceType: String, Sendable {
    case mock = "Demo / Mock"
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case none = "Tidak Ada"
}

/// Kontrak protokol untuk penyedia data pemutar media
@MainActor
public protocol MediaProviding: AnyObject {
    var sourceType: MediaSourceType { get }
    var currentTrack: MediaTrack? { get }
    var isPlaying: Bool { get }
    var playbackProgress: Double { get } // 0.0 sampai 1.0
    
    func togglePlayback()
    func nextTrack()
    func previousTrack()
    func seek(to progress: Double)
}

/// Implementasi Mock Provider untuk pengujian dan pengembangan UI
@MainActor
public final class MockMediaProvider: ObservableObject, MediaProviding {
    public let sourceType: MediaSourceType = .mock
    
    @Published public private(set) var currentTrack: MediaTrack?
    @Published public private(set) var isPlaying: Bool = true
    @Published public private(set) var playbackProgress: Double = 0.38
    
    private let playlist: [MediaTrack] = [
        MediaTrack(title: "Starboy", artist: "The Weeknd", album: "Starboy", duration: 230),
        MediaTrack(title: "Blinding Lights", artist: "The Weeknd", album: "After Hours", duration: 200),
        MediaTrack(title: "Save Your Tears", artist: "The Weeknd", album: "After Hours", duration: 215)
    ]
    private var currentIndex: Int = 0
    private var progressTimer: AnyCancellable?
    
    public init() {
        self.currentTrack = playlist.first
        startSimulationTimer()
    }
    
    private func startSimulationTimer() {
        progressTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isPlaying, let track = self.currentTrack else { return }
                let step = 1.0 / track.duration
                if self.playbackProgress + step >= 1.0 {
                    self.nextTrack()
                } else {
                    self.playbackProgress += step
                }
            }
    }
    
    public func togglePlayback() {
        isPlaying.toggle()
    }
    
    public func nextTrack() {
        currentIndex = (currentIndex + 1) % playlist.count
        currentTrack = playlist[currentIndex]
        playbackProgress = 0.0
    }
    
    public func previousTrack() {
        currentIndex = (currentIndex - 1 + playlist.count) % playlist.count
        currentTrack = playlist[currentIndex]
        playbackProgress = 0.0
    }
    
    public func seek(to progress: Double) {
        playbackProgress = min(max(progress, 0.0), 1.0)
    }
}

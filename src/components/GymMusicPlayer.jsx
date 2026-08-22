import { useState } from "react";
import { Music, ExternalLink, X, Play } from "lucide-react";
import { useI18n } from "../lib/i18n.jsx";

const SPOTIFY_PLAYLISTS = [
  { id: "37i9dQZF1DX76Wlfdnj7AP", name: "Beast Mode", genre: "Heavy Lifts & Rap", icon: "🔥" },
  { id: "37i9dQZF1DXdLEN7aqioXM", name: "Gym Motivation", genre: "High Energy & Pump", icon: "⚡" },
  { id: "37i9dQZF1DX8tZsk68tuED", name: "Cardio EDM", genre: "House & Dance Workout", icon: "🎧" },
  { id: "37i9dQZF1DWWY64vggyipV", name: "Phonk & Hardstyle", genre: "Dark Synth & Heavy Bass", icon: "🦾" },
  { id: "37i9dQZF1DX35oM5Joy0JJ", name: "Cool Down", genre: "Recovery & Stretching", icon: "🧘" },
];

const YOUTUBE_WORKOUT_MIXES = [
  {
    id: "jfKfPfyJRdk",
    title: "1h Hip-Hop Gym Focus Beats",
    genre: "Focus & Rhythm",
    icon: "🎧",
  },
  {
    id: "fBNq4K2d6zI",
    title: "Aggressive Gym Phonk & Hardstyle Mix",
    genre: "Maximum Adrenaline",
    icon: "🦾",
  },
  {
    id: "5qap5aO4i9A",
    title: "Dark Techno Heavy Workout Mix",
    genre: "High Energy Club",
    icon: "⚡",
  },
  {
    id: "4xDzrJKXOOY",
    title: "Epic Cinematic Gym Pump",
    genre: "Heroic Motivation",
    icon: "🔥",
  },
];

function extractYouTubeId(urlOrId) {
  if (!urlOrId) return "";
  const match = urlOrId.match(
    /(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=))([\w-]{11})/
  );
  return match ? match[1] : urlOrId.trim();
}

export default function GymMusicPlayer({ onClose }) {
  const { t } = useI18n();
  const [activeTab, setActiveTab] = useState("spotify"); // "spotify" | "youtube"

  // Spotify State
  const [selectedSpotify, setSelectedSpotify] = useState(SPOTIFY_PLAYLISTS[0]);

  // YouTube State
  const [activeYoutubeId, setActiveYoutubeId] = useState(YOUTUBE_WORKOUT_MIXES[0].id);
  const [customYoutubeInput, setCustomYoutubeInput] = useState("");

  const handleApplyCustomYoutube = (e) => {
    e.preventDefault();
    const id = extractYouTubeId(customYoutubeInput);
    if (id && id.length >= 10) {
      setActiveYoutubeId(id);
    }
  };

  return (
    <div className="gym-music-overlay" onClick={onClose}>
      <div className="gym-music-card" onClick={(e) => e.stopPropagation()}>
        {/* Header */}
        <div className="gym-music-header">
          <div className="gym-music-title">
            <Music size={18} className="text-accent" />
            <span>GYM SOUNDTRACK</span>
          </div>
          <button className="live-close-btn" onClick={onClose}>
            <X size={16} />
          </button>
        </div>

        {/* 2 Tabs: Spotify & YouTube */}
        <div className="live-mode-switch" style={{ marginBottom: "8px" }}>
          <button
            className={`live-mode-btn ${activeTab === "spotify" ? "active" : ""}`}
            onClick={() => setActiveTab("spotify")}
          >
            🟢 Spotify Playlists
          </button>
          <button
            className={`live-mode-btn ${activeTab === "youtube" ? "active" : ""}`}
            onClick={() => setActiveTab("youtube")}
          >
            ▶️ YouTube Workout
          </button>
        </div>

        {/* SPOTIFY TAB */}
        {activeTab === "spotify" && (
          <div className="spotify-tab-content">
            <div className="playlist-chip-row">
              {SPOTIFY_PLAYLISTS.map((pl) => (
                <button
                  key={pl.id}
                  className={`playlist-chip ${selectedSpotify.id === pl.id ? "active" : ""}`}
                  onClick={() => setSelectedSpotify(pl)}
                >
                  <span>{pl.icon}</span>
                  <div>
                    <div className="pl-name">{pl.name}</div>
                    <div className="pl-genre">{pl.genre}</div>
                  </div>
                </button>
              ))}
            </div>

            <div className="spotify-embed-wrapper">
              <iframe
                title="Spotify Gym Playlist"
                src={`https://open.spotify.com/embed/playlist/${selectedSpotify.id}?utm_source=generator&theme=0`}
                width="100%"
                height="152"
                frameBorder="0"
                allow="autoplay; clipboard-write; encrypted-media; fullscreen; picture-in-picture"
                loading="lazy"
                style={{ borderRadius: "14px", border: "none" }}
              />
            </div>

            <a
              href={`spotify:playlist:${selectedSpotify.id}`}
              className="spotify-app-link"
              target="_blank"
              rel="noreferrer"
            >
              <ExternalLink size={14} /> In Spotify App öffnen
            </a>
          </div>
        )}

        {/* YOUTUBE TAB */}
        {activeTab === "youtube" && (
          <div className="spotify-tab-content">
            <div className="playlist-chip-row">
              {YOUTUBE_WORKOUT_MIXES.map((mix) => (
                <button
                  key={mix.id}
                  className={`playlist-chip ${activeYoutubeId === mix.id ? "active" : ""}`}
                  onClick={() => setActiveYoutubeId(mix.id)}
                >
                  <span>{mix.icon}</span>
                  <div>
                    <div className="pl-name">{mix.title}</div>
                    <div className="pl-genre">{mix.genre}</div>
                  </div>
                </button>
              ))}
            </div>

            <div className="youtube-embed-wrapper">
              <iframe
                title="YouTube Workout Mix"
                width="100%"
                height="190"
                src={`https://www.youtube.com/embed/${activeYoutubeId}?autoplay=1&enablejsapi=1`}
                frameBorder="0"
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                allowFullScreen
                style={{ borderRadius: "14px", border: "none" }}
              />
            </div>

            <form onSubmit={handleApplyCustomYoutube} className="custom-youtube-form">
              <input
                type="text"
                className="custom-youtube-input"
                placeholder="YouTube Link einfügen …"
                value={customYoutubeInput}
                onChange={(e) => setCustomYoutubeInput(e.target.value)}
              />
              <button type="submit" className="custom-youtube-btn">
                Abspielen
              </button>
            </form>
          </div>
        )}
      </div>
    </div>
  );
}

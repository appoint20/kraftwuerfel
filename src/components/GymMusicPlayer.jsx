import { useState, useRef, useEffect } from "react";
import {
  Music,
  Play,
  Pause,
  SkipForward,
  SkipBack,
  Volume2,
  Upload,
  ExternalLink,
  X,
  Radio,
  Trash2,
} from "lucide-react";
import { useI18n } from "../lib/i18n.jsx";

// 1. Spotify Playlists
const SPOTIFY_PLAYLISTS = [
  { id: "37i9dQZF1DX76Wlfdnj7AP", name: "Beast Mode", genre: "Heavy Lifts & Rap", icon: "🔥" },
  { id: "37i9dQZF1DXdLEN7aqioXM", name: "Gym Motivation", genre: "High Energy & Pump", icon: "⚡" },
  { id: "37i9dQZF1DX8tZsk68tuED", name: "Cardio & Electronic", genre: "EDM & House Workout", icon: "🎧" },
  { id: "37i9dQZF1DWWY64vggyipV", name: "Phonk & Hardstyle", genre: "Dark Synth & Heavy Bass", icon: "🦾" },
  { id: "37i9dQZF1DX35oM5Joy0JJ", name: "Cool Down & Recovery", genre: "Stretching & Ambient", icon: "🧘" },
];

// 2. Apple Music Playlists
const APPLE_MUSIC_PLAYLISTS = [
  {
    id: "pl.u-38018xEuWJrbgP",
    embedUrl: "https://embed.music.apple.com/us/playlist/gym-workout-motivation/pl.u-38018xEuWJrbgP",
    appUrl: "https://music.apple.com/us/playlist/gym-workout-motivation/pl.u-38018xEuWJrbgP",
    name: "Pure Gym Motivation",
    genre: "Apple Music Workout",
    icon: "🍎",
  },
  {
    id: "pl.u-6mo44a4TBx1mK2",
    embedUrl: "https://embed.music.apple.com/us/playlist/heavy-lifting-beast-mode/pl.u-6mo44a4TBx1mK2",
    appUrl: "https://music.apple.com/us/playlist/heavy-lifting-beast-mode/pl.u-6mo44a4TBx1mK2",
    name: "Beast Mode Lifting",
    genre: "Rock & Heavy Hip-Hop",
    icon: "🔥",
  },
  {
    id: "pl.u-9N9lvbLu2eL0d8",
    embedUrl: "https://embed.music.apple.com/us/playlist/cardio-pump-edm/pl.u-9N9lvbLu2eL0d8",
    appUrl: "https://music.apple.com/us/playlist/cardio-pump-edm/pl.u-9N9lvbLu2eL0d8",
    name: "Cardio Pump EDM",
    genre: "High BPM Electronic",
    icon: "⚡",
  },
];

// 3. YouTube Gym Mixes
const YOUTUBE_WORKOUT_MIXES = [
  {
    id: "jfKfPfyJRdk",
    title: "1h Lofi / Hip-Hop Gym Focus Beats",
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
    title: "Epic Orchestral & Cinematic Gym Pump",
    genre: "Heroic Motivation",
    icon: "🔥",
  },
];

// IndexedDB Helper for Persistent Offline Music
const DB_NAME = "kraftwuerfel_music_db";
const STORE_NAME = "offline_tracks";

function openMusicDB() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, 1);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        db.createObjectStore(STORE_NAME, { keyPath: "id" });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function saveOfflineTrack(track) {
  try {
    const db = await openMusicDB();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, "readwrite");
      const store = tx.objectStore(STORE_NAME);
      store.put(track);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  } catch (err) {
    console.warn("Error saving track:", err);
  }
}

async function getOfflineTracks() {
  try {
    const db = await openMusicDB();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, "readonly");
      const store = tx.objectStore(STORE_NAME);
      const request = store.getAll();
      request.onsuccess = () => resolve(request.result || []);
      request.onerror = () => reject(request.error);
    });
  } catch {
    return [];
  }
}

async function deleteOfflineTrack(id) {
  try {
    const db = await openMusicDB();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, "readwrite");
      const store = tx.objectStore(STORE_NAME);
      store.delete(id);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
  } catch (err) {
    console.warn("Error deleting track:", err);
  }
}

function extractYouTubeId(urlOrId) {
  if (!urlOrId) return "";
  const match = urlOrId.match(
    /(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=))([\w-]{11})/
  );
  return match ? match[1] : urlOrId.trim();
}

export default function GymMusicPlayer({ onClose }) {
  const { t } = useI18n();
  const [activeTab, setActiveTab] = useState("apple"); // "apple" | "spotify" | "youtube" | "offline"
  
  // Spotify State
  const [selectedSpotify, setSelectedSpotify] = useState(SPOTIFY_PLAYLISTS[0]);

  // Apple Music State
  const [selectedApple, setSelectedApple] = useState(APPLE_MUSIC_PLAYLISTS[0]);

  // YouTube State
  const [selectedYoutube, setSelectedYoutube] = useState(YOUTUBE_WORKOUT_MIXES[0]);
  const [customYoutubeInput, setCustomYoutubeInput] = useState("");
  const [activeYoutubeVideoId, setActiveYoutubeVideoId] = useState(YOUTUBE_WORKOUT_MIXES[0].id);

  // Offline MP3 Tracks State
  const [offlineTracks, setOfflineTracks] = useState([]);
  const [currentTrackIndex, setCurrentTrackIndex] = useState(0);
  const [isPlayingLocal, setIsPlayingLocal] = useState(false);
  const [isSynthBeatActive, setIsSynthBeatActive] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [activeAudioBlobUrl, setActiveAudioBlobUrl] = useState(null);

  const audioRef = useRef(null);
  const synthTimerRef = useRef(null);
  const audioCtxRef = useRef(null);

  // Load saved offline MP3 tracks from IndexedDB on mount
  useEffect(() => {
    getOfflineTracks().then((tracks) => {
      setOfflineTracks(tracks);
      if (tracks.length > 0) {
        loadTrackIntoPlayer(tracks[0]);
      }
    });

    return () => {
      if (synthTimerRef.current) clearInterval(synthTimerRef.current);
      if (audioCtxRef.current) {
        try {
          audioCtxRef.current.close();
        } catch {}
      }
      if (activeAudioBlobUrl) {
        URL.revokeObjectURL(activeAudioBlobUrl);
      }
    };
  }, []);

  const loadTrackIntoPlayer = (track) => {
    if (!track || !track.blob) return;
    if (activeAudioBlobUrl) URL.revokeObjectURL(activeAudioBlobUrl);
    const url = URL.createObjectURL(track.blob);
    setActiveAudioBlobUrl(url);
  };

  const handleFileUpload = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const newTrack = {
      id: `${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
      name: file.name.replace(/\.[^/.]+$/, ""),
      sizeMb: (file.size / (1024 * 1024)).toFixed(1),
      addedAt: new Date().toISOString(),
      blob: file,
    };

    await saveOfflineTrack(newTrack);
    const updated = await getOfflineTracks();
    setOfflineTracks(updated);
    const newIdx = updated.findIndex((t) => t.id === newTrack.id);
    setCurrentTrackIndex(newIdx >= 0 ? newIdx : 0);
    loadTrackIntoPlayer(newTrack);
    setIsPlayingLocal(true);
    setIsSynthBeatActive(false);
  };

  const handleDeleteTrack = async (id, e) => {
    e.stopPropagation();
    await deleteOfflineTrack(id);
    const updated = await getOfflineTracks();
    setOfflineTracks(updated);
    if (updated.length > 0) {
      setCurrentTrackIndex(0);
      loadTrackIntoPlayer(updated[0]);
    } else {
      setActiveAudioBlobUrl(null);
      setIsPlayingLocal(false);
    }
  };

  const handleSelectOfflineTrack = (idx) => {
    setCurrentTrackIndex(idx);
    loadTrackIntoPlayer(offlineTracks[idx]);
    setIsPlayingLocal(true);
  };

  const togglePlayLocal = () => {
    if (!audioRef.current) return;
    if (isPlayingLocal) {
      audioRef.current.pause();
      setIsPlayingLocal(false);
    } else {
      audioRef.current.play().catch(() => {});
      setIsPlayingLocal(true);
    }
  };

  const playNextTrack = () => {
    if (offlineTracks.length === 0) return;
    const nextIdx = (currentTrackIndex + 1) % offlineTracks.length;
    setCurrentTrackIndex(nextIdx);
    loadTrackIntoPlayer(offlineTracks[nextIdx]);
    setIsPlayingLocal(true);
  };

  const playPrevTrack = () => {
    if (offlineTracks.length === 0) return;
    const prevIdx = (currentTrackIndex - 1 + offlineTracks.length) % offlineTracks.length;
    setCurrentTrackIndex(prevIdx);
    loadTrackIntoPlayer(offlineTracks[prevIdx]);
    setIsPlayingLocal(true);
  };

  // Custom YouTube URL submit
  const handleApplyCustomYoutube = (e) => {
    e.preventDefault();
    const id = extractYouTubeId(customYoutubeInput);
    if (id && id.length >= 10) {
      setActiveYoutubeVideoId(id);
    }
  };

  // Offline Web Audio Synth Metronome / Beat (128 BPM)
  const toggleSynthBeat = () => {
    if (isSynthBeatActive) {
      if (synthTimerRef.current) clearInterval(synthTimerRef.current);
      setIsSynthBeatActive(false);
      return;
    }

    try {
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      if (!audioCtxRef.current) {
        audioCtxRef.current = new AudioContext();
      }
      if (audioCtxRef.current.state === "suspended") {
        audioCtxRef.current.resume();
      }

      setIsSynthBeatActive(true);
      setIsPlayingLocal(false);
      if (audioRef.current) audioRef.current.pause();

      let step = 0;
      const bpm = 128;
      const intervalMs = (60 / bpm / 4) * 1000;

      synthTimerRef.current = setInterval(() => {
        const ctx = audioCtxRef.current;
        if (!ctx) return;

        // Kick on 1, 5, 9, 13
        if (step % 4 === 0) {
          const osc = ctx.createOscillator();
          const gain = ctx.createGain();
          osc.type = "sine";
          osc.frequency.setValueAtTime(140, ctx.currentTime);
          osc.frequency.exponentialRampToValueAtTime(38, ctx.currentTime + 0.08);
          gain.gain.setValueAtTime(0.75, ctx.currentTime);
          gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.12);
          osc.connect(gain);
          gain.connect(ctx.destination);
          osc.start();
          osc.stop(ctx.currentTime + 0.12);
        }

        // Hi-Hat on offbeats
        if (step % 4 === 2) {
          const osc = ctx.createOscillator();
          const gain = ctx.createGain();
          osc.type = "square";
          osc.frequency.setValueAtTime(8000, ctx.currentTime);
          gain.gain.setValueAtTime(0.12, ctx.currentTime);
          gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.04);
          osc.connect(gain);
          gain.connect(ctx.destination);
          osc.start();
          osc.stop(ctx.currentTime + 0.04);
        }

        step = (step + 1) % 16;
      }, intervalMs);
    } catch (err) {
      console.warn("Synth audio error:", err);
    }
  };

  const formatTime = (secs) => {
    if (isNaN(secs)) return "0:00";
    const m = Math.floor(secs / 60);
    const s = Math.floor(secs % 60);
    return `${m}:${s < 10 ? "0" : ""}${s}`;
  };

  const activeTrack = offlineTracks[currentTrackIndex];

  return (
    <div className="gym-music-overlay" onClick={onClose}>
      <div className="gym-music-card" onClick={(e) => e.stopPropagation()}>
        {/* Header */}
        <div className="gym-music-header">
          <div className="gym-music-title">
            <Music size={18} className="text-accent" />
            <span>GYM AUDIO CENTER</span>
          </div>
          <button className="live-close-btn" onClick={onClose}>
            <X size={16} />
          </button>
        </div>

        {/* 4 Multi-Service Tabs */}
        <div className="music-tab-bar">
          <button
            className={`music-tab-item ${activeTab === "apple" ? "active" : ""}`}
            onClick={() => setActiveTab("apple")}
          >
            🍎 Apple Music
          </button>
          <button
            className={`music-tab-item ${activeTab === "spotify" ? "active" : ""}`}
            onClick={() => setActiveTab("spotify")}
          >
            🟢 Spotify
          </button>
          <button
            className={`music-tab-item ${activeTab === "youtube" ? "active" : ""}`}
            onClick={() => setActiveTab("youtube")}
          >
            ▶️ YouTube
          </button>
          <button
            className={`music-tab-item ${activeTab === "offline" ? "active" : ""}`}
            onClick={() => setActiveTab("offline")}
          >
            💾 MP3 / Offline
          </button>
        </div>

        {/* 1. APPLE MUSIC TAB */}
        {activeTab === "apple" && (
          <div className="spotify-tab-content">
            <div className="playlist-chip-row">
              {APPLE_MUSIC_PLAYLISTS.map((pl) => (
                <button
                  key={pl.id}
                  className={`playlist-chip ${selectedApple.id === pl.id ? "active" : ""}`}
                  onClick={() => setSelectedApple(pl)}
                >
                  <span>{pl.icon}</span>
                  <div>
                    <div className="pl-name">{pl.name}</div>
                    <div className="pl-genre">{pl.genre}</div>
                  </div>
                </button>
              ))}
            </div>

            {/* Apple Music Official Embed Player */}
            <div className="spotify-embed-wrapper">
              <iframe
                title="Apple Music Workout"
                allow="autoplay *; encrypted-media *; fullscreen *; clipboard-write"
                frameBorder="0"
                height="175"
                style={{ width: "100%", maxWidth: "100%", overflow: "hidden", borderRadius: "14px", border: "none" }}
                sandbox="allow-forms allow-popups allow-same-origin allow-scripts allow-storage-access-by-user-activation allow-top-navigation-by-user-activation"
                src={selectedApple.embedUrl}
              />
            </div>

            <a
              href={selectedApple.appUrl}
              className="apple-music-app-link"
              target="_blank"
              rel="noreferrer"
            >
              <ExternalLink size={14} /> In Apple Music App öffnen
            </a>
          </div>
        )}

        {/* 2. SPOTIFY TAB */}
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

        {/* 3. YOUTUBE VIDEO & AUDIO TAB */}
        {activeTab === "youtube" && (
          <div className="spotify-tab-content">
            <div className="playlist-chip-row">
              {YOUTUBE_WORKOUT_MIXES.map((mix) => (
                <button
                  key={mix.id}
                  className={`playlist-chip ${activeYoutubeVideoId === mix.id ? "active" : ""}`}
                  onClick={() => {
                    setSelectedYoutube(mix);
                    setActiveYoutubeVideoId(mix.id);
                  }}
                >
                  <span>{mix.icon}</span>
                  <div>
                    <div className="pl-name">{mix.title}</div>
                    <div className="pl-genre">{mix.genre}</div>
                  </div>
                </button>
              ))}
            </div>

            {/* Embedded YouTube Player */}
            <div className="youtube-embed-wrapper">
              <iframe
                title="YouTube Workout Mix"
                width="100%"
                height="190"
                src={`https://www.youtube.com/embed/${activeYoutubeVideoId}?autoplay=1&enablejsapi=1`}
                frameBorder="0"
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                allowFullScreen
                style={{ borderRadius: "14px", border: "none" }}
              />
            </div>

            {/* Custom YouTube URL Form */}
            <form onSubmit={handleApplyCustomYoutube} className="custom-youtube-form">
              <input
                type="text"
                className="custom-youtube-input"
                placeholder="Eigenen YouTube Video Link einfügen …"
                value={customYoutubeInput}
                onChange={(e) => setCustomYoutubeInput(e.target.value)}
              />
              <button type="submit" className="custom-youtube-btn">
                Abspielen
              </button>
            </form>
          </div>
        )}

        {/* 4. OFFLINE MP3 & PERSISTENT AUDIO PLAYLIST */}
        {activeTab === "offline" && (
          <div className="local-music-tab-content">
            {/* Offline Synth Beat Generator */}
            <div className="offline-synth-card">
              <div className="synth-info">
                <Radio size={20} className={isSynthBeatActive ? "text-accent live-dot-pulse" : "text-muted"} />
                <div>
                  <div className="synth-title">Offline Gym Pump Beat (128 BPM)</div>
                  <div className="synth-sub">Läuft 100% ohne Internet im Gym-Keller</div>
                </div>
              </div>
              <button
                className={`synth-toggle-btn ${isSynthBeatActive ? "active" : ""}`}
                onClick={toggleSynthBeat}
              >
                {isSynthBeatActive ? <Pause size={16} /> : <Play size={16} fill="currentColor" />}
                <span>{isSynthBeatActive ? "Stoppen" : "Starten"}</span>
              </button>
            </div>

            {/* MP3 & Audio Upload Button */}
            <label className="music-upload-box">
              <Upload size={20} className="text-accent" />
              <div className="upload-title">MP3 / Audio-Datei importieren & dauerhaft speichern</div>
              <div className="upload-sub">Gespeicherte Songs bleiben offline in der App verfügbar</div>
              <input
                type="file"
                accept="audio/*"
                onChange={handleFileUpload}
                style={{ display: "none" }}
              />
            </label>

            {/* Active Track Audio Player Bar */}
            {activeAudioBlobUrl && (
              <div className="offline-player-card">
                <audio
                  ref={audioRef}
                  src={activeAudioBlobUrl}
                  autoPlay
                  onTimeUpdate={() => {
                    if (audioRef.current) {
                      setCurrentTime(audioRef.current.currentTime);
                      setDuration(audioRef.current.duration || 0);
                    }
                  }}
                  onEnded={playNextTrack}
                  onPlay={() => setIsPlayingLocal(true)}
                  onPause={() => setIsPlayingLocal(false)}
                />

                <div className="offline-player-top">
                  <div className="offline-track-info">
                    <div className="offline-track-name">
                      {activeTrack?.name || "Audio Track"}
                    </div>
                    <div className="offline-track-time">
                      {formatTime(currentTime)} / {formatTime(duration)}
                    </div>
                  </div>
                  <Volume2 size={16} className="text-accent" />
                </div>

                {/* Progress Bar */}
                <div
                  className="music-progress-bar"
                  onClick={(e) => {
                    if (audioRef.current && duration > 0) {
                      const rect = e.currentTarget.getBoundingClientRect();
                      const pos = (e.clientX - rect.left) / rect.width;
                      audioRef.current.currentTime = pos * duration;
                    }
                  }}
                >
                  <div
                    className="music-progress-fill"
                    style={{ width: `${duration > 0 ? (currentTime / duration) * 100 : 0}%` }}
                  />
                </div>

                {/* Controls */}
                <div className="offline-controls-row">
                  <button className="offline-ctrl-btn" onClick={playPrevTrack}>
                    <SkipBack size={18} />
                  </button>
                  <button className="offline-main-play-btn" onClick={togglePlayLocal}>
                    {isPlayingLocal ? <Pause size={20} /> : <Play size={20} fill="currentColor" />}
                  </button>
                  <button className="offline-ctrl-btn" onClick={playNextTrack}>
                    <SkipForward size={18} />
                  </button>
                </div>
              </div>
            )}

            {/* Saved Playlist Tracks List */}
            {offlineTracks.length > 0 && (
              <div className="offline-playlist-list">
                <div className="section-label" style={{ margin: "4px 0" }}>
                  Gespeicherte Offline-Tracks ({offlineTracks.length})
                </div>
                {offlineTracks.map((t, idx) => (
                  <div
                    key={t.id}
                    className={`offline-track-item ${currentTrackIndex === idx ? "active" : ""}`}
                    onClick={() => handleSelectOfflineTrack(idx)}
                  >
                    <div className="offline-track-index">{idx + 1}</div>
                    <div className="offline-track-col">
                      <div className="offline-track-title">{t.name}</div>
                      <div className="offline-track-size">{t.sizeMb} MB · Gespeichert</div>
                    </div>
                    <button
                      className="offline-track-del"
                      onClick={(e) => handleDeleteTrack(t.id, e)}
                      title="Löschen"
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

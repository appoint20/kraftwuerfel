import { useState, useRef, useEffect } from "react";
import { Music, Play, Pause, Volume2, Upload, ExternalLink, X, Radio } from "lucide-react";
import { useI18n } from "../lib/i18n.jsx";

const SPOTIFY_PLAYLISTS = [
  { id: "37i9dQZF1DX76Wlfdnj7AP", name: "Beast Mode", genre: "Heavy Lifts & Rap", icon: "🔥" },
  { id: "37i9dQZF1DXdLEN7aqioXM", name: "Gym Motivation", genre: "High Energy & Pump", icon: "⚡" },
  { id: "37i9dQZF1DX8tZsk68tuED", name: "Cardio & Electronic", genre: "EDM & House Workout", icon: "🎧" },
  { id: "37i9dQZF1DWWY64vggyipV", name: "Phonk & Hardstyle", genre: "Dark Synth & Heavy Bass", icon: "🦾" },
  { id: "37i9dQZF1DX35oM5Joy0JJ", name: "Cool Down & Recovery", genre: "Stretching & Ambient", icon: "🧘" },
];

export default function GymMusicPlayer({ onClose }) {
  const { t } = useI18n();
  const [activeTab, setActiveTab] = useState("spotify"); // "spotify" | "local"
  const [selectedPlaylist, setSelectedPlaylist] = useState(SPOTIFY_PLAYLISTS[0]);

  // Local / Custom Audio State
  const [localAudioUrl, setLocalAudioUrl] = useState(null);
  const [localAudioName, setLocalAudioName] = useState("");
  const [isPlayingLocal, setIsPlayingLocal] = useState(false);
  const [isSynthBeatActive, setIsSynthBeatActive] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);

  const audioRef = useRef(null);
  const synthTimerRef = useRef(null);
  const audioCtxRef = useRef(null);

  // Clean up on unmount
  useEffect(() => {
    return () => {
      if (synthTimerRef.current) clearInterval(synthTimerRef.current);
      if (audioCtxRef.current) {
        try { audioCtxRef.current.close(); } catch {}
      }
    };
  }, []);

  const handleFileUpload = (e) => {
    const file = e.target.files?.[0];
    if (file) {
      if (localAudioUrl) URL.revokeObjectURL(localAudioUrl);
      const url = URL.createObjectURL(file);
      setLocalAudioUrl(url);
      setLocalAudioName(file.name.replace(/\.[^/.]+$/, ""));
      setIsPlayingLocal(true);
      setIsSynthBeatActive(false);
    }
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

  // Offline Web Audio Synth Beat Generator (High Energy Gym Metronome/Beat)
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
      const intervalMs = (60 / bpm / 4) * 1000; // 16th notes

      synthTimerRef.current = setInterval(() => {
        const ctx = audioCtxRef.current;
        if (!ctx) return;

        // Kick on 1, 5, 9, 13 (4/4 Kick drum)
        if (step % 4 === 0) {
          const osc = ctx.createOscillator();
          const gain = ctx.createGain();
          osc.type = "sine";
          osc.frequency.setValueAtTime(140, ctx.currentTime);
          osc.frequency.exponentialRampToValueAtTime(38, ctx.currentTime + 0.08);
          gain.gain.setValueAtTime(0.7, ctx.currentTime);
          gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.12);
          osc.connect(gain);
          gain.connect(ctx.destination);
          osc.start();
          osc.stop(ctx.currentTime + 0.12);
        }

        // Hi-hat on offbeats (step 2, 6, 10, 14)
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

  return (
    <div className="gym-music-overlay" onClick={onClose}>
      <div className="gym-music-card" onClick={(e) => e.stopPropagation()}>
        <div className="gym-music-header">
          <div className="gym-music-title">
            <Music size={18} className="text-accent" />
            <span>GYM MUSIC & BEATS</span>
          </div>
          <button className="live-close-btn" onClick={onClose}>
            <X size={16} />
          </button>
        </div>

        {/* Tab Switcher */}
        <div className="live-mode-switch" style={{ marginBottom: "12px" }}>
          <button
            className={`live-mode-btn ${activeTab === "spotify" ? "active" : ""}`}
            onClick={() => setActiveTab("spotify")}
          >
            Spotify Playlists
          </button>
          <button
            className={`live-mode-btn ${activeTab === "local" ? "active" : ""}`}
            onClick={() => setActiveTab("local")}
          >
            Offline & Lokale Musik
          </button>
        </div>

        {/* SPOTIFY TAB */}
        {activeTab === "spotify" && (
          <div className="spotify-tab-content">
            <div className="playlist-chip-row">
              {SPOTIFY_PLAYLISTS.map((pl) => (
                <button
                  key={pl.id}
                  className={`playlist-chip ${selectedPlaylist.id === pl.id ? "active" : ""}`}
                  onClick={() => setSelectedPlaylist(pl)}
                >
                  <span>{pl.icon}</span>
                  <div>
                    <div className="pl-name">{pl.name}</div>
                    <div className="pl-genre">{pl.genre}</div>
                  </div>
                </button>
              ))}
            </div>

            {/* Embedded Spotify Player */}
            <div className="spotify-embed-wrapper">
              <iframe
                title="Spotify Gym Playlist"
                src={`https://open.spotify.com/embed/playlist/${selectedPlaylist.id}?utm_source=generator&theme=0`}
                width="100%"
                height="152"
                frameBorder="0"
                allow="autoplay; clipboard-write; encrypted-media; fullscreen; picture-in-picture"
                loading="lazy"
                style={{ borderRadius: "14px", border: "none" }}
              />
            </div>

            <a
              href={`spotify:playlist:${selectedPlaylist.id}`}
              className="spotify-app-link"
              target="_blank"
              rel="noreferrer"
            >
              <ExternalLink size={14} /> In Spotify-App öffnen
            </a>
          </div>
        )}

        {/* OFFLINE / LOCAL TAB */}
        {activeTab === "local" && (
          <div className="local-music-tab-content">
            {/* Built-in Offline Gym Metronome / Beat */}
            <div className="offline-synth-card">
              <div className="synth-info">
                <Radio size={20} className={isSynthBeatActive ? "text-accent live-dot-pulse" : "text-muted"} />
                <div>
                  <div className="synth-title">Offline Gym Pump Beat (128 BPM)</div>
                  <div className="synth-sub">Funktioniert ohne Internet direkt im Browser</div>
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

            <div className="or-divider">
              <span>ODER EIGENE DATEI LADEN</span>
            </div>

            {/* Upload MP3 / Audio */}
            <label className="music-upload-box">
              <Upload size={22} className="text-accent" />
              <div className="upload-title">Audio-Datei von Smartphone wählen</div>
              <div className="upload-sub">Unterstützt MP3, M4A, WAV, FLAC</div>
              <input
                type="file"
                accept="audio/*"
                onChange={handleFileUpload}
                style={{ display: "none" }}
              />
            </label>

            {localAudioUrl && (
              <div className="local-player-strip">
                <audio
                  ref={audioRef}
                  src={localAudioUrl}
                  autoPlay
                  loop
                  onTimeUpdate={() => {
                    if (audioRef.current) {
                      setCurrentTime(audioRef.current.currentTime);
                      setDuration(audioRef.current.duration || 0);
                    }
                  }}
                  onPlay={() => setIsPlayingLocal(true)}
                  onPause={() => setIsPlayingLocal(false)}
                />
                <button className="local-play-btn" onClick={togglePlayLocal}>
                  {isPlayingLocal ? <Pause size={18} /> : <Play size={18} fill="currentColor" />}
                </button>
                <div className="local-meta">
                  <div className="local-title">{localAudioName}</div>
                  <div className="local-time">
                    {formatTime(currentTime)} / {formatTime(duration)}
                  </div>
                </div>
                <Volume2 size={16} className="text-accent" />
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

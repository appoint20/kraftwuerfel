import { useRef, useState } from "react";
import { X, Play, Pause, SkipBack, SkipForward, Plus, Trash2, WifiOff, Radio, Music } from "lucide-react";
import { useMusic } from "../lib/music.jsx";
import { useI18n } from "../lib/i18n.jsx";
import { formatBytes } from "../lib/musicLibrary.js";

/*
  Zwei getrennte Welten, bewusst nicht vermischt:

  "Offline" ist die eigentliche Gym-Playlist — Dateien aus IndexedDB, die ohne
  Empfang laufen. Das ist der Standard-Tab.

  "Streaming" lädt Spotify/YouTube erst nach einem Klick. Vorher geht kein
  Request und kein Cookie an die beiden raus; ein eingebetteter Player setzt
  sonst schon beim Öffnen Tracker, was ohne Einwilligung nicht sauber ist.
*/

const SPOTIFY_PLAYLISTS = [
  { id: "37i9dQZF1DX76Wlfdnj7AP", label: "Beast Mode" },
  { id: "37i9dQZF1DXcF6B6QPhFDv", label: "Rock Workout" },
  { id: "37i9dQZF1DX70RN3TfWWJh", label: "Power Hour" },
];

export default function GymMusicPlayer({ onClose }) {
  const { t } = useI18n();
  const music = useMusic();
  const fileRef = useRef(null);
  const [tab, setTab] = useState("offline");
  const [streamConsent, setStreamConsent] = useState(false);
  const [activeStream, setActiveStream] = useState(null);
  const [importing, setImporting] = useState(false);

  const onPick = async (e) => {
    setImporting(true);
    await music.addFiles(e.target.files);
    setImporting(false);
    e.target.value = "";
  };

  const totalBytes = music.tracks.reduce((sum, tr) => sum + (tr.size || 0), 0);

  return (
    <div className="music-sheet">
      <div className="music-head">
        <div className="music-title">
          <Music size={16} />
          <span>{t("music.title")}</span>
        </div>
        <button className="music-close" onClick={onClose} title={t("music.close")}>
          <X size={18} />
        </button>
      </div>

      <div className="music-tabs">
        <button className={tab === "offline" ? "active" : ""} onClick={() => setTab("offline")}>
          <WifiOff size={13} /> {t("music.offline")}
        </button>
        <button className={tab === "stream" ? "active" : ""} onClick={() => setTab("stream")}>
          <Radio size={13} /> {t("music.streaming")}
        </button>
      </div>

      {tab === "offline" ? (
        <>
          {music.current && (
            <div className="music-now">
              <div className="music-now-title">{music.current.title}</div>
              <div className="music-controls">
                <button onClick={music.prev} title={t("music.prev")}>
                  <SkipBack size={18} />
                </button>
                <button className="primary" onClick={music.toggle} title={t("music.playPause")}>
                  {music.isPlaying ? <Pause size={20} fill="currentColor" /> : <Play size={20} fill="currentColor" />}
                </button>
                <button onClick={music.next} title={t("music.next")}>
                  <SkipForward size={18} />
                </button>
              </div>
              <div className="music-now-hint">{t("music.lockScreenHint")}</div>
            </div>
          )}

          {music.tracks.length === 0 ? (
            <div className="music-empty">
              <WifiOff size={22} />
              <div className="music-empty-title">{t("music.emptyTitle")}</div>
              <div className="music-empty-text">{t("music.emptyText")}</div>
            </div>
          ) : (
            <div className="music-list">
              {music.tracks.map((track) => {
                const active = music.current?.id === track.id;
                return (
                  <div className={`music-row ${active ? "active" : ""}`} key={track.id}>
                    <button className="music-row-play" onClick={() => music.playTrack(track.id)}>
                      {active && music.isPlaying ? (
                        <Pause size={14} fill="currentColor" />
                      ) : (
                        <Play size={14} fill="currentColor" />
                      )}
                    </button>
                    <div className="music-row-main">
                      <div className="music-row-title">{track.title}</div>
                      <div className="music-row-meta">{formatBytes(track.size)}</div>
                    </div>
                    <button
                      className="music-row-del"
                      onClick={() => music.removeTrack(track.id)}
                      title={t("music.remove")}
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                );
              })}
            </div>
          )}

          <input
            ref={fileRef}
            type="file"
            accept="audio/*"
            multiple
            onChange={onPick}
            style={{ display: "none" }}
          />
          <button className="music-add" onClick={() => fileRef.current?.click()} disabled={importing}>
            <Plus size={16} /> {importing ? t("music.importing") : t("music.add")}
          </button>

          {music.tracks.length > 0 && (
            <div className="music-usage">{t("music.usage", { size: formatBytes(totalBytes), n: music.tracks.length })}</div>
          )}
          {!music.available && <div className="auth-error">{t("music.noStorage")}</div>}
        </>
      ) : (
        <>
          {!streamConsent ? (
            <div className="music-consent">
              <Radio size={20} />
              <div className="music-empty-title">{t("music.consentTitle")}</div>
              <div className="music-empty-text">{t("music.consentText")}</div>
              <button className="music-add" onClick={() => setStreamConsent(true)}>
                {t("music.consentAccept")}
              </button>
            </div>
          ) : activeStream ? (
            <>
              <iframe
                className="music-frame"
                src={activeStream}
                title={t("music.streaming")}
                allow="autoplay; clipboard-write; encrypted-media; picture-in-picture"
                loading="lazy"
              />
              <button className="music-add" onClick={() => setActiveStream(null)}>
                <X size={15} /> {t("music.closeStream")}
              </button>
            </>
          ) : (
            <div className="music-list">
              {SPOTIFY_PLAYLISTS.map((pl) => (
                <button
                  className="music-row as-button"
                  key={pl.id}
                  onClick={() => setActiveStream(`https://open.spotify.com/embed/playlist/${pl.id}?theme=0`)}
                >
                  <Radio size={14} />
                  <div className="music-row-main">
                    <div className="music-row-title">{pl.label}</div>
                    <div className="music-row-meta">Spotify · {t("music.needsInternet")}</div>
                  </div>
                </button>
              ))}
            </div>
          )}
        </>
      )}
    </div>
  );
}

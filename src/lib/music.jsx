import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";
import { musicLibrary } from "./musicLibrary.js";

/*
  Ein einziges <audio>-Element für die ganze App, hier oben verwaltet.

  Warum zentral: das Sperrbildschirm-Widget (MediaSession) hängt an echtem,
  laufendem Audio. Nur wenn wirklich etwas abgespielt wird, zeigt iOS die Karte
  an — und die Apple Watch spiegelt sie dann automatisch unter "Now Playing".
  Ein früherer Stand hat diese Karte nachgebaut; das war eine Attrappe im
  eigenen Fenster und auf dem Sperrbildschirm nie zu sehen.

  Das Training kann seinen Kontext dazulegen (aktuelle Übung, Satz, Pause), der
  dann zusammen mit dem Titel auf dem Sperrbildschirm steht.
*/

const MusicContext = createContext(null);

const ARTWORK = [
  { src: "/icon-192.png", sizes: "192x192", type: "image/png" },
  { src: "/icon-512.png", sizes: "512x512", type: "image/png" },
];

export function MusicProvider({ children }) {
  const audioRef = useRef(null);
  const objectUrlRef = useRef(null);

  const [tracks, setTracks] = useState([]);
  const [currentId, setCurrentId] = useState(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [error, setError] = useState("");
  // Was gerade trainiert wird — kommt aus der Live-Session.
  const [workout, setWorkout] = useState(null);

  if (!audioRef.current && typeof Audio !== "undefined") {
    audioRef.current = new Audio();
    audioRef.current.preload = "metadata";
    /*
      Damit die Musik weiterläuft, wenn das Display ausgeht: iOS braucht dafür
      UIBackgroundModes=audio in der Info.plist (ist gesetzt) und ein Element,
      das nicht als stummes Inline-Video behandelt wird.
    */
    audioRef.current.setAttribute("playsinline", "");
    audioRef.current.loop = false;
  }

  const reload = useCallback(async () => {
    if (!musicLibrary.available) return;
    try {
      setTracks(await musicLibrary.list());
    } catch {
      setError("library-unavailable");
    }
  }, []);

  useEffect(() => {
    reload();
  }, [reload]);

  const current = useMemo(() => tracks.find((t) => t.id === currentId) || null, [tracks, currentId]);

  const revokeUrl = () => {
    if (objectUrlRef.current) {
      URL.revokeObjectURL(objectUrlRef.current);
      objectUrlRef.current = null;
    }
  };

  const playTrack = useCallback(async (id) => {
    const audio = audioRef.current;
    if (!audio) return;
    try {
      const blob = await musicLibrary.blobFor(id);
      if (!blob) return;
      revokeUrl();
      objectUrlRef.current = URL.createObjectURL(blob);
      audio.src = objectUrlRef.current;
      setCurrentId(id);
      await audio.play();
      setIsPlaying(true);
      setError("");
    } catch {
      setError("playback-failed");
      setIsPlaying(false);
    }
  }, []);

  const pause = useCallback(() => {
    audioRef.current?.pause();
    setIsPlaying(false);
  }, []);

  const resume = useCallback(async () => {
    const audio = audioRef.current;
    if (!audio) return;
    if (!audio.src && tracks[0]) {
      await playTrack(tracks[0].id);
      return;
    }
    try {
      await audio.play();
      setIsPlaying(true);
    } catch {
      setError("playback-failed");
    }
  }, [tracks, playTrack]);

  const toggle = useCallback(() => (isPlaying ? pause() : resume()), [isPlaying, pause, resume]);

  const step = useCallback(
    (dir) => {
      if (tracks.length === 0) return;
      const idx = tracks.findIndex((t) => t.id === currentId);
      const next = tracks[(((idx === -1 ? 0 : idx) + dir) % tracks.length + tracks.length) % tracks.length];
      if (next) playTrack(next.id);
    },
    [tracks, currentId, playTrack]
  );

  const next = useCallback(() => step(1), [step]);
  const prev = useCallback(() => step(-1), [step]);

  const addFiles = useCallback(
    async (fileList) => {
      const files = Array.from(fileList || []);
      if (files.length === 0) return 0;
      try {
        const added = await musicLibrary.add(files);
        await reload();
        return added.length;
      } catch {
        setError("import-failed");
        return 0;
      }
    },
    [reload]
  );

  const removeTrack = useCallback(
    async (id) => {
      if (id === currentId) {
        pause();
        setCurrentId(null);
        revokeUrl();
      }
      await musicLibrary.remove(id);
      await reload();
    },
    [currentId, pause, reload]
  );

  // Song zu Ende -> nächster. Ohne das endet die Playlist nach einem Titel.
  useEffect(() => {
    const audio = audioRef.current;
    if (!audio) return;
    const onEnded = () => next();
    const onPlay = () => setIsPlaying(true);
    const onPause = () => setIsPlaying(false);
    audio.addEventListener("ended", onEnded);
    audio.addEventListener("play", onPlay);
    audio.addEventListener("pause", onPause);
    return () => {
      audio.removeEventListener("ended", onEnded);
      audio.removeEventListener("play", onPlay);
      audio.removeEventListener("pause", onPause);
    };
  }, [next]);

  useEffect(() => () => revokeUrl(), []);

  /*
    Die Sperrbildschirm-Karte. Titel ist die Übung, wenn gerade trainiert wird —
    das ist die Information, für die man das Handy aus der Tasche holt. Der Song
    steht in der Zeile darunter.
  */
  useEffect(() => {
    if (typeof navigator === "undefined" || !("mediaSession" in navigator)) return;
    if (!current && !workout) return;

    const trackTitle = current?.title || "";
    const title = workout?.exercise || trackTitle || "Kraftwürfel";
    const artistParts = [];
    if (workout?.detail) artistParts.push(workout.detail);
    if (workout?.exercise && trackTitle) artistParts.push(trackTitle);

    try {
      navigator.mediaSession.metadata = new window.MediaMetadata({
        title,
        artist: artistParts.join(" · ") || "Kraftwürfel",
        album: workout?.title || "Kraftwürfel",
        artwork: ARTWORK,
      });
      navigator.mediaSession.playbackState = isPlaying ? "playing" : "paused";
    } catch {
      // MediaMetadata fehlt in manchen Browsern — dann eben ohne Karte.
    }
  }, [current, workout, isPlaying]);

  // Die Knöpfe auf Sperrbildschirm und Uhr sollen auch etwas tun.
  useEffect(() => {
    if (typeof navigator === "undefined" || !("mediaSession" in navigator)) return;
    const handlers = [
      ["play", () => resume()],
      ["pause", () => pause()],
      ["nexttrack", () => next()],
      ["previoustrack", () => prev()],
    ];
    handlers.forEach(([action, fn]) => {
      try {
        navigator.mediaSession.setActionHandler(action, fn);
      } catch {
        // Aktion wird auf dieser Plattform nicht unterstützt
      }
    });
    return () => {
      handlers.forEach(([action]) => {
        try {
          navigator.mediaSession.setActionHandler(action, null);
        } catch {
          // ignorieren
        }
      });
    };
  }, [resume, pause, next, prev]);

  const value = {
    available: musicLibrary.available,
    tracks,
    current,
    isPlaying,
    error,
    reload,
    addFiles,
    removeTrack,
    playTrack,
    toggle,
    pause,
    resume,
    next,
    prev,
    setWorkoutContext: setWorkout,
  };

  return <MusicContext.Provider value={value}>{children}</MusicContext.Provider>;
}

export function useMusic() {
  const ctx = useContext(MusicContext);
  if (!ctx) throw new Error("useMusic muss innerhalb von MusicProvider verwendet werden");
  return ctx;
}

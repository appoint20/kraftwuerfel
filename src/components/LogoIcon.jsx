export default function LogoIcon({ size = 30 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 48 48" fill="none">
      {/* Würfel-Silhouette im Hintergrund */}
      <rect x="15" y="15" width="18" height="18" rx="3" transform="rotate(45 24 24)" fill="currentColor" opacity="0.22" />
      {/* Frau (links) */}
      <circle cx="16" cy="14" r="3.6" fill="currentColor" />
      <path d="M16 18.4c-3.6 0-5.7 2.6-5.7 6.2V31h11.4v-6.4c0-3.6-2.1-6.2-5.7-6.2z" fill="currentColor" />
      <rect x="3.5" y="19" width="7.5" height="2.4" rx="1.2" fill="currentColor" />
      <rect x="2" y="17.4" width="2.8" height="5.6" rx="1" fill="currentColor" />
      <rect x="9.2" y="17.4" width="2.8" height="5.6" rx="1" fill="currentColor" />
      {/* Mann (rechts) */}
      <circle cx="32" cy="14" r="3.6" fill="currentColor" />
      <path d="M32 18.4c-3.6 0-5.7 2.6-5.7 6.2V31h11.4v-6.4c0-3.6-2.1-6.2-5.7-6.2z" fill="currentColor" />
      <rect x="37" y="19" width="7.5" height="2.4" rx="1.2" fill="currentColor" />
      <rect x="35.8" y="17.4" width="2.8" height="5.6" rx="1" fill="currentColor" />
      <rect x="43" y="17.4" width="2.8" height="5.6" rx="1" fill="currentColor" />
    </svg>
  );
}

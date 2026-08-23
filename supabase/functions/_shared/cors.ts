/*
  CORS für Web UND native App.

  Die native App meldet sich nicht mit einer https-Adresse, sondern mit
  capacitor://localhost (iOS) bzw. http://localhost (Android). Steht in
  ALLOWED_ORIGIN nur die Web-Domain, blockt der Browser im WKWebView jeden
  Aufruf — die Anfrage kommt gar nicht erst bei der Function an. Genau so sieht
  "KI kann keine Anfrage schicken" aus.

  Deshalb: ALLOWED_ORIGIN darf eine Kommaliste sein, die Ursprünge der nativen
  Hüllen sind immer erlaubt, und zurückgegeben wird der anfragende Ursprung.
*/

const NATIVE_ORIGINS = [
  "capacitor://localhost",
  "ionic://localhost",
  "http://localhost",
  "https://localhost",
];

export function corsHeaders(req: Request): Record<string, string> {
  const configured = (Deno.env.get("ALLOWED_ORIGIN") || "")
    .split(",")
    .map((o) => o.trim())
    .filter(Boolean);

  const origin = req.headers.get("Origin") || "";
  const allowAll = configured.length === 0 || configured.includes("*");
  const allowed = allowAll || configured.includes(origin) || NATIVE_ORIGINS.includes(origin);

  return {
    // Ohne echten Ursprung (native fetch schickt manchmal keinen) reicht "*".
    "Access-Control-Allow-Origin": allowed ? origin || "*" : configured[0],
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}

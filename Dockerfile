# Kraftwürfel — Frontend
#
# Zwei Stufen: Node baut das Bundle, nginx liefert es aus. Im Endimage steckt
# kein Node und kein node_modules — nur statische Dateien und ein Webserver.
#
# Die Supabase-Werte landen NICHT im Build. Sie werden beim Containerstart nach
# /usr/share/nginx/html/env.js geschrieben (siehe docker/40-kraftwuerfel-env.sh),
# damit dasselbe Image von Staging nach Produktion wandern kann.
#
#   docker build -t kraftwuerfel .
#   docker run --rm -p 8080:8080 \
#     -e VITE_SUPABASE_URL=https://xxx.supabase.co \
#     -e VITE_SUPABASE_ANON_KEY=eyJ... \
#     kraftwuerfel

FROM node:22-alpine AS build

WORKDIR /app

# Erst die Manifeste: solange sie sich nicht ändern, bleibt der npm-Layer im Cache.
COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build


FROM nginx:1.27-alpine AS runtime

# Render gibt den Port über die Umgebung vor; lokal ist 8080 der Standard.
ENV PORT=8080

# Als Vorlage, nicht als fertige Konfiguration: der Port kommt erst beim Start dazu.
COPY docker/nginx.conf /etc/nginx/kraftwuerfel.conf.template
COPY docker/40-kraftwuerfel-env.sh /docker-entrypoint.d/40-kraftwuerfel-env.sh
RUN chmod +x /docker-entrypoint.d/40-kraftwuerfel-env.sh

COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 8080

# nginx' eigenes Entrypoint führt vor dem Start alles in /docker-entrypoint.d aus.
CMD ["nginx", "-g", "daemon off;"]

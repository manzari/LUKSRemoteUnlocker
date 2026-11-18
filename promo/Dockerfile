# syntax=docker/dockerfile:1
# Landing page: this directory is the content, the apppage engine renders it.
# The engine comes in as the named build context `engine` (see compose.yaml).
# The steps follow the engine's own Dockerfile; keep them in line with it.

FROM ruby:3.2-alpine AS builder

RUN apk add --no-cache build-base ca-certificates curl git jq nodejs npm

WORKDIR /site

COPY --from=engine Gemfile Gemfile.lock ./
RUN bundle install

COPY --from=engine package.json package-lock.json ./
RUN npm ci --ignore-scripts

COPY --from=engine . .

# Legal pages come from the engrossify API. This layer depends only on the two
# files below, so edits to texts and images do not render them again.
COPY _config.yml engrossify.yaml /project/
ARG ENGROSSIFY_URL=https://legal.guestlist.ink
ARG LEGAL_RENDER_VERSION=1
# Local builds only: placeholder legal pages instead of failing without the key.
ARG ALLOW_PLACEHOLDER_LEGAL=0
RUN --mount=type=secret,id=engrossify_api_key \
    echo "legal render v${LEGAL_RENDER_VERSION}" && \
    if [ "$ALLOW_PLACEHOLDER_LEGAL" = "1" ]; then \
        echo "WARNING: ALLOW_PLACEHOLDER_LEGAL=1, shipping placeholder legal pages" >&2; \
        sh bin/render-legal.sh /project; \
    elif [ ! -s /run/secrets/engrossify_api_key ]; then \
        echo "ERROR: build secret 'engrossify_api_key' is missing or empty (set ENGROSSIFY_API_KEY)." >&2; \
        exit 1; \
    else \
        ENGROSSIFY_API_KEY="$(cat /run/secrets/engrossify_api_key)" \
        ENGROSSIFY_URL="$ENGROSSIFY_URL" \
        sh bin/render-legal.sh /project; \
    fi

COPY . /project/
RUN sh bin/apply-content.sh /project

RUN mkdir -p src/assets/css/vendor/fontawesome src/assets/fonts/fontawesome src/assets/fonts/inter && \
    npm run copy-assets && \
    sed -i 's|../webfonts/|/assets/fonts/fontawesome/|g' src/assets/css/vendor/fontawesome/all.min.css

RUN bundle exec jekyll build --source src && \
    find _site -type d -exec chmod 755 {} + && \
    find _site -type f -exec chmod 644 {} +

FROM nginx:alpine

COPY --from=builder /site/_site /usr/share/nginx/html
COPY --from=builder /site/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /site/nginx-security-headers.conf /etc/nginx/snippets/security-headers.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

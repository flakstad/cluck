# Cluck Web Server Example

This example keeps the HTTP routing in pure Cluck, uses the separate top-level
`ring/` library tree for request/response/middleware helpers, and leaves the
server loop to the `spiffy` egg through `ring.adapter.spiffy`.

## Library Split

- `examples/cluck/web-server/main.clk` holds the pure Cluck route logic
- `ring/request.clk`, `ring/response.clk`, and `ring/middleware.clk` are the
  reusable Ring-style libraries
- `ring/adapter/spiffy.clk` is the only mixed Cluck/Scheme layer
- `ring/README.md` documents the split in one place
- `ring.middleware.cookies`, `ring.middleware.session`,
  `ring.middleware.params`, `ring.middleware.keyword-params`,
  `ring.middleware.gzip`, `ring.middleware.head`, `ring.middleware.content-length`,
  and `ring.middleware.not-modified` are the helper layers used by the example

## Layout

```text
examples/cluck/web-server/
  README.md
  main.clk
  run.scm
```

## Install

Install the eggs once in your CHICKEN environment:

```bash
chicken-install spiffy zlib hmac sha2 message-digest message-digest-utils
```

`spiffy` pulls in the `intarweb` and `uri-common` dependencies used by the
adapter in `ring.adapter.spiffy`. The Ring session and anti-forgery helpers use
the CHICKEN `hmac`, `sha2`, `message-digest`, and `message-digest-utils` eggs
for HMAC-SHA256 and SHA-256 hashing. `ring.middleware.gzip` uses the CHICKEN
`zlib` egg for gzip response compression.

## Run

Start the server from source with an optional listen port:

```bash
csi -q -s examples/cluck/web-server/run.scm 8081
```

If you omit the port argument, the server listens on `8080`.

The Ring library itself requires an explicit session secret. This example
supplies one from `CLUCK_WEB_SESSION_SECRET` when it is set, and otherwise
generates a fresh per-process secret so the demo still starts cleanly. Set an
explicit value in production if you want stable sessions across restarts.

## Routes

- `/` renders the landing page
- `/health` returns a short health check page
- `/echo/<tail>` echoes the trailing path text
- `/cookie` sets and reads a demo browser cookie
- `/visit` increments a signed session counter
- `/params` shows parsed query and form params for `GET` and `POST`
- anything else returns a 404 page
- non-`GET` requests return a 405 page unless the request targets `/params`

The handler also supports `HEAD /health` and conditional `GET /health` with an
`If-None-Match` header.

When the client sends `Accept-Encoding: gzip`, the example compresses the HTML
responses with gzip and adds `Content-Encoding: gzip`.

## Manual Test

While the server is running, try these requests from another terminal:

```bash
curl -i http://127.0.0.1:8081/
curl -i http://127.0.0.1:8081/health
curl -i http://127.0.0.1:8081/echo/cluck
curl -i -c /tmp/cluck.cookies -b /tmp/cluck.cookies http://127.0.0.1:8081/cookie
curl -i -c /tmp/cluck.cookies -b /tmp/cluck.cookies http://127.0.0.1:8081/visit
curl -i -b /tmp/cluck.cookies http://127.0.0.1:8081/visit
curl -i 'http://127.0.0.1:8081/params?name=cluck&name=egg'
curl -i -X POST -H 'Content-Type: application/x-www-form-urlencoded' --data 'name=cluck&theme=dark' http://127.0.0.1:8081/params
curl -I http://127.0.0.1:8081/health
curl -i -H 'If-None-Match: "cluck-health-v1"' http://127.0.0.1:8081/health
curl -i -H 'Accept-Encoding: gzip' --compressed http://127.0.0.1:8081/
curl -i http://127.0.0.1:8081/missing
curl -i -X POST http://127.0.0.1:8081/
```

The responses should include `Content-Type: text/html; charset=utf-8`, which
comes from `ring.middleware/wrap-content-type` around the handler.

The gzip request should include `Content-Encoding: gzip`; `curl --compressed`
will transparently decompress it for display.

The cookie and session requests should reuse the same cookie jar so the
counter increments on repeated `visit` calls.

Stop the server with `Ctrl+C` when you are done.

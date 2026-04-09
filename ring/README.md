# Separate Ring Library Tree

This directory holds the sync-only Ring-style libraries used by the Cluck
examples. It is intentionally separate from the `cluck.*` namespaces: the
public APIs live under `ring.request`, `ring.response`, `ring.middleware`, and
`ring.adapter.spiffy`.

## Layout

```text
ring/
  README.md
  util.clk
  util/
    crypto.clk
    body.clk
    cookie.clk
    json.clk
    params.clk
  request.clk
  response.clk
  middleware.clk
  middleware/
    cors.clk
    exceptions.clk
    cookies.clk
    content-length.clk
    gzip.clk
    head.clk
    json.clk
    keyword-params.clk
    request-id.clk
    not-modified.clk
    params.clk
    resource.clk
    session.clk
    session/
      cookie.clk
  adapter/
    spiffy.clk
```

## Namespace Split

- `ring.request` for pure request helpers
- `ring.response` for pure response helpers
- `ring.middleware` for pure middleware wrappers
- `ring.util.body` and `ring.util.json` for shared body and JSON conversion helpers
- `ring.middleware.cookies` for request cookie parsing and response cookie serialization
- `ring.middleware.params` and `ring.middleware.keyword-params` for query/form parsing
- `ring.middleware.request-id`, `ring.middleware.exceptions`, and `ring.middleware.json` for common app and API seams
- `ring.middleware.defaults` and `ring.middleware.anti-forgery` for the standard browser-app security stack
- `ring.middleware.cors` and `ring.middleware.resource` for production web app boundaries
- `ring.middleware.gzip` for gzip response compression
- `ring.middleware.session` and `ring.middleware.session.cookie` for signed cookie sessions
- `ring.middleware.head`, `ring.middleware.content-length`, and `ring.middleware.not-modified` for common HTTP response behavior
- `ring.adapter.spiffy` for the mixed Cluck/Scheme HTTP adapter

The adapter is the only layer that knows about Spiffy or Intarweb. The
request/response/middleware layers stay in pure Cluck and are safe to use in
tests or other handlers without any server-specific code.

## Scope

This layer is synchronous only. It does not implement Ring async handlers or
websocket support.

The current middleware set is aimed at ordinary web apps and APIs: cookies,
sessions, query and form params, request IDs, exception handling, JSON body and
response helpers, CORS, static resources, HEAD handling, content length,
conditional GET, defaults/security presets, body-size limits, and
anti-forgery protection.

## Install

Install the crypto and server eggs once in your CHICKEN environment before
using the full Ring stack:

```bash
chicken-install spiffy zlib hmac sha2 message-digest message-digest-utils
```

`ring.adapter.spiffy` depends on `spiffy`. Signed-cookie sessions and the
anti-forgery stack depend on `hmac`, `sha2`, `message-digest`, and
`message-digest-utils`. `ring.middleware.gzip` depends on `zlib`.

## Security Notes

- Signed cookie sessions use the CHICKEN `hmac` and `sha2` eggs for
  HMAC-SHA256. `ring.middleware.session` and `ring.middleware.defaults`
  require an explicit session secret; they do not silently mint a fallback
  secret for production use.
- `ring.middleware.defaults` only trusts `X-Forwarded-*` host and scheme
  headers from configured `:trusted-proxies`.
- Absolute redirects only reflect a direct `Host` header when it matches
  `:trusted-hosts`. Otherwise the library falls back to the server-configured
  host.
- `ring.middleware.resource` rejects symlinks and applies a default
  `:max-body-bytes` limit of 8 MiB for static files.

## Current Limitations

- Signed-cookie sessions protect integrity, not confidentiality. Session data
  is visible to the client and should not contain secrets.
- Request bodies, multipart uploads, JSON payloads, and static resources are
  still buffered in memory. Size limits exist, but this is not a streaming
  server stack yet.
- Response compression is gzip-only for now. Brotli is tracked separately and
  still needs a backend.
- Reverse-proxy safety still depends on correct deployment configuration for
  `:trusted-proxies` and `:trusted-hosts`.
- The crypto primitives come from CHICKEN eggs, but the constant-time string
  comparison helper is still local code.
- The automated coverage is strong for the current feature surface, but this
  library has not had adversarial network fuzzing, browser-level integration
  testing, or serious load/soak testing.
- The stack is sync-only. It does not cover async handlers or websocket
  support.

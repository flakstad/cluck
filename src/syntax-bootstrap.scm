(include "src/syntax-bootstrap-core.scm")

(set-read-syntax! #\: read-keyword)
(set-read-syntax! #\[ read-vector-literal)
(set-read-syntax! #\{ read-map-literal)
(set-sharp-read-syntax! #\_ read-discard)
(set-sharp-read-syntax! #\{ read-set-literal)

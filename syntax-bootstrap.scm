(import (chicken load))

(load-relative "syntax-bootstrap-core.scm")

(set-read-syntax! #\: read-keyword)
(set-read-syntax! #\[ read-vector-literal)
(set-read-syntax! #\{ read-map-literal)
(set-sharp-read-syntax! #\{ read-set-literal)

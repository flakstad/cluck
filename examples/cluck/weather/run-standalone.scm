(import scheme
        (chicken base)
        (chicken load)
        (chicken process-context)
        (prefix http-client http:)
        (prefix json json:)
        (prefix uri-common uri:))

(begin-for-syntax
  (import (chicken file)
          (chicken process-context))
  (include "syntax-bootstrap.scm")
  (include "cluck-standalone-prelude.scm"))

;; Bundle the runtime and the Cluck app source into one compilation unit.
(include "cluck.scm")
(include "cluck/string.clk")
(include "cluck/edn.clk")

;; Mark the bundled namespace as already available so `ns :require` does not
;; try to locate it on disk at runtime.
(hash-table-set! *cluck-loaded-namespaces* 'cluck.string #t)
(hash-table-set! *cluck-loaded-namespaces* 'cluck.edn #t)
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.weather #t)

;; The bundled weather source is preprocessed to use prefix-style aliases for
;; bundled Cluck namespaces, so bind those aliases explicitly in the launcher.
(define str:blank? blank?)
(define str:trim trim)
(define str:join join)
(define str:lower-case lower-case)
(define str:upper-case upper-case)
(define str:capitalize capitalize)
(define str:includes? includes?)
(define str:split split)
(define str:split-lines split-lines)
(define str:starts-with? starts-with?)
(define str:ends-with? ends-with?)
(define edn:read-string read-string)

(include "examples/cluck/weather/standalone.clk")

(main (command-line-arguments))

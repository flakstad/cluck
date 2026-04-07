(import scheme
        (chicken base)
        (chicken load)
        (chicken process-context))

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

(include "examples/cluck/weather.clk")

(main (command-line-arguments))

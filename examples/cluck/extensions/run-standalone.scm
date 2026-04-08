(import scheme
        (chicken base)
        (chicken load)
        (chicken process-context))

(begin-for-syntax
  (import (chicken file)
          (chicken process-context))
  (include "src/syntax-bootstrap.scm")
  (include "src/cluck-standalone-prelude.scm"))

(include "src/cluck.scm")

(hash-table-set! *cluck-loaded-namespaces* 'cluck.string #t)
(hash-table-set! *cluck-loaded-namespaces* 'cluck.fs #t)
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.extensions #t)

(include "src/cluck/string.clk")
(include "src/cluck/fs.clk")

(hash-table-set! *cluck-loaded-namespaces* 'cluck.string #t)
(hash-table-set! *cluck-loaded-namespaces* 'cluck.fs #t)
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.extensions #t)

(include "examples/cluck/extensions/main.clk")

(main (command-line-arguments))

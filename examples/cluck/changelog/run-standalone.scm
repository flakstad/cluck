(import scheme
        (chicken base)
        (chicken load)
        (chicken process-context))

(begin-for-syntax
  (import (chicken file)
          (chicken process-context))
  (include "syntax-bootstrap.scm")
  (include "cluck-standalone-prelude.scm"))

(include "cluck.scm")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.string #t)
(hash-table-set! *cluck-loaded-namespaces* 'cluck.process #t)
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.changelog #t)
(include "cluck/string.clk")
(include "cluck/process.clk")

(hash-table-set! *cluck-loaded-namespaces* 'cluck.string #t)
(hash-table-set! *cluck-loaded-namespaces* 'cluck.process #t)
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.changelog #t)

(include "examples/cluck/changelog/main.clk")

(main (command-line-arguments))

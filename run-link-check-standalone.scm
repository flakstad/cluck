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
(hash-table-set! *cluck-loaded-namespaces* 'cluck.fs #t)
(hash-table-set! *cluck-loaded-namespaces* 'cluck.links #t)
(include "cluck/string.clk")
(include "cluck/fs.clk")

(hash-table-set! *cluck-loaded-namespaces* 'cluck.string #t)
(hash-table-set! *cluck-loaded-namespaces* 'cluck.fs #t)
(hash-table-set! *cluck-loaded-namespaces* 'cluck.links #t)

(include "examples/cluck/link-check.clk")

(##core#let ((args (command-line-arguments)))
  (if (null? args)
      (error "Usage: run-link-check-standalone.scm <file> ...")
      (main args)))

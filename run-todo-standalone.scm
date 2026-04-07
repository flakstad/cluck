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
(hash-table-set! *cluck-loaded-namespaces* 'cluck.todo #t)
(include "cluck/string.clk")
(include "cluck/fs.clk")

(hash-table-set! *cluck-loaded-namespaces* 'cluck.string #t)
(hash-table-set! *cluck-loaded-namespaces* 'cluck.fs #t)
(hash-table-set! *cluck-loaded-namespaces* 'cluck.todo #t)

(include "examples/cluck/todo.clk")

(main (command-line-arguments))

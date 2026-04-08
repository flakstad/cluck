(import scheme
        (chicken base)
        (chicken load))

(begin-for-syntax
  (import (chicken file)
          (chicken process-context))
  (include "src/syntax-bootstrap.scm")
  (include "src/cluck-standalone-prelude.scm"))

(include "src/cluck.scm")

(hash-table-set! *cluck-loaded-namespaces* 'cluck.sdl3 #t)

(include "cluck/sdl3.clk")

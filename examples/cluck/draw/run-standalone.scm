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
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.draw.sdl3 #t)
(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.draw #t)

(include "src/cluck/string.clk")
(include "examples/cluck/draw/sdl3.clk")
(include "examples/cluck/draw/main.clk")

(main (command-line-arguments))

(import scheme
        (chicken base)
        (chicken load))

(begin-for-syntax
  (import (chicken file)
          (chicken process-context))
  (include "src/syntax-bootstrap.scm")
  (include "src/cluck-standalone-prelude.scm"))

(include "src/cluck.scm")

(include "examples/cluck/draw/src/sdl3/raw.clk")
(include "examples/cluck/draw/src/sdl3/native.clk")
(include "examples/cluck/draw/src/sdl3.clk")

(hash-table-set! *cluck-loaded-namespaces* 'cluck.examples.draw.sdl3 #t)

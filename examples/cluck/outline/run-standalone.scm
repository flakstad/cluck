(import scheme
        (chicken base)
        (chicken load)
        (chicken process-context))

(begin-for-syntax
  (import (chicken file)
          (chicken process-context))
  (include "src/syntax-bootstrap.scm")
  (include "src/cluck-standalone-prelude.scm"))

;; Bundle the runtime and the Cluck app source into one compilation unit.
(include "src/cluck.scm")
(include "src/cluck/string.clk")

;; Mark the bundled namespaces as already available so `ns :require` does not
;; try to locate them on disk at runtime.
(hash-table-set! *cluck-loaded-namespaces* 'cluck.string #t)
(include "src/cluck/fs.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.fs #t)

(include "examples/cluck/outline/main.clk")

(define (outline-standalone-port->string port)
  (##core#let loop ((chars '()))
    (##core#let ((ch (read-char port)))
      (if (eof-object? ch)
          (list->string (reverse chars))
          (loop (cons ch chars))))))

(define (outline-standalone-file->string path)
  (call-with-input-file path outline-standalone-port->string))

(##core#let ((args (command-line-arguments)))
  (if (null? args)
      (main "stdin"
            (outline-standalone-port->string (current-input-port)))
      (if (= (length args) 1)
          (##core#let ((path (car args)))
            (main path (outline-standalone-file->string path)))
          (error "Usage: run-outline-standalone.scm [file]"))))

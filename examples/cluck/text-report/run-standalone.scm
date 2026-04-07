(import scheme
        (chicken base)
        (chicken file)
        (chicken load)
        (chicken port)
        (chicken process-context))

(begin-for-syntax
  (import (chicken file)
          (chicken process-context))
  (include "src/syntax-bootstrap.scm")
  (include "src/cluck-standalone-prelude.scm"))

;; Bundle the runtime and the Cluck app source into one compilation unit.
(include "src/cluck.scm")
(include "cluck/string.clk")

;; Mark the bundled namespace as already available so `ns :require` does not
;; try to locate it on disk at runtime.
(hash-table-set! *cluck-loaded-namespaces* 'cluck.string #t)

(include "examples/cluck/text-report/main.clk")

(define (text-report-standalone-port->string port)
  (##core#let loop ((chars '()))
    (##core#let ((ch (read-char port)))
      (if (eof-object? ch)
          (list->string (reverse chars))
          (loop (cons ch chars))))))

(define (text-report-standalone-file->string path)
  (call-with-input-file path text-report-standalone-port->string))

(##core#let ((args (command-line-arguments)))
  (if (null? args)
      (main "stdin"
            (text-report-standalone-port->string (current-input-port)))
      (if (= (length args) 1)
          (##core#let ((path (car args)))
            (main path (text-report-standalone-file->string path)))
          (error "Usage: run-text-report-standalone.scm [file]"))))

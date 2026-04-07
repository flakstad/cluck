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
(include "cluck/string.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.string #t)

(include "examples/cluck/csv.clk")
(hash-table-set! *cluck-loaded-namespaces* 'cluck.csv #t)

(define (csv-standalone-suffix? path suffix)
  (let* ((path-len (string-length path))
         (suffix-len (string-length suffix)))
    (and (>= path-len suffix-len)
         (string=? (substring path (- path-len suffix-len) path-len)
                   suffix))))

(define (csv-standalone-default-separator source)
  (if (or (csv-standalone-suffix? source ".tsv")
          (csv-standalone-suffix? source ".TSV"))
      "\t"
      ","))

(define (csv-standalone-read-input path)
  (if (or (not path) (string=? path "-"))
      (##core#let ((port (current-input-port)))
        (csv-standalone-read-input-loop port '()))
      (call-with-input-file path
        (lambda (port)
          (csv-standalone-read-input-loop port '())))))

(define (csv-standalone-read-input-loop port chars)
  (##core#let ((ch (read-char port)))
    (if (eof-object? ch)
        (list->string (reverse chars))
        (csv-standalone-read-input-loop port (cons ch chars)))))

(##core#let ((args (command-line-arguments)))
  (##core#let loop ((rest args) (separator #f) (header? #t) (source #f))
    (if (null? rest)
        (let* ((stdin? (or (not source)
                           (string=? source "-")))
               (separator (or separator
                              (if (and source (not stdin?))
                                  (csv-standalone-default-separator source)
                                  ",")))
               (source-name (if stdin?
                                "stdin"
                                source))
               (text (csv-standalone-read-input source)))
          (main source-name text separator header?))
        (##core#let ((arg (car rest)))
          (if (string=? arg "--tsv")
              (loop (cdr rest) "\t" header? source)
              (if (string=? arg "--csv")
                  (loop (cdr rest) "," header? source)
                  (if (string=? arg "--no-header")
                      (loop (cdr rest) separator #f source)
                      (if (string=? arg "--header")
                          (loop (cdr rest) separator #t source)
                          (if (and (> (string-length arg) 0)
                                   (char=? (string-ref arg 0) #\-))
                              (error "Usage: run-csv-standalone.scm [--csv|--tsv] [--header|--no-header] [file]")
                              (if (not source)
                                  (loop (cdr rest) separator header? arg)
                                  (error "Usage: run-csv-standalone.scm [--csv|--tsv] [--header|--no-header] [file]"))))))))))
)

(import (chicken base)
        (chicken file)
        (chicken load)
        (chicken port)
        (chicken process-context))

(define (cluck-cli-usage)
  (display "Usage: cluck [repl] [-i] [-e EXPR] [-l FILE] [FILE ...]") (newline)
  (display "  cluck                 start a cluck REPL") (newline)
  (display "  cluck repl            start a cluck REPL") (newline)
  (display "  cluck -e EXPR         evaluate one or more cluck forms") (newline)
  (display "  cluck -l FILE         load a cluck source file") (newline)
  (display "  cluck FILE ...        load one or more files") (newline)
  (display "  cluck -i ...          load/eval first, then enter the REPL") (newline))

(define (cluck-cli-eval-form form)
  (call-with-values
   (lambda ()
     (eval form (interaction-environment)))
   cluck-repl-print-results))

(define (cluck-cli-eval-string expr)
  (call-with-input-string
   expr
   (lambda (port)
     (let loop ()
       (let ((form (read port)))
         (unless (eof-object? form)
           (cluck-cli-eval-form form)
           (loop)))))))

(define (cluck-cli-main args)
  (let loop ((xs args)
             (interactive? #f)
             (did-action? #f))
    (cond
      ((null? xs)
       (if (or interactive? (not did-action?))
           (cluck-repl)
           (void)))
      ((or (string=? (car xs) "-h")
           (string=? (car xs) "--help"))
       (cluck-cli-usage))
      ((or (string=? (car xs) "repl")
           (string=? (car xs) "--repl"))
       (cluck-repl))
      ((or (string=? (car xs) "-i")
           (string=? (car xs) "--interactive"))
       (loop (cdr xs) #t did-action?))
      ((string=? (car xs) "-e")
       (if (pair? (cdr xs))
           (begin
             (cluck-cli-eval-string (cadr xs))
             (loop (cddr xs) interactive? #t))
           (error "cluck: -e expects an expression")))
      ((string=? (car xs) "-l")
       (if (pair? (cdr xs))
           (begin
             (load-file (cadr xs))
             (loop (cddr xs) interactive? #t))
           (error "cluck: -l expects a file path")))
      (else
       (load-file (car xs))
       (loop (cdr xs) interactive? #t)))))

(load-relative "cluck.scm")

;; Preserve the convenient top-level alias for the REPL and command-line runs.
(define read-string cluck-core-read-string)
(cluck-intern! (current-ns) 'read-string read-string)
(cluck-put-doc! (current-ns) 'read-string "Read one Cluck form from STRING.")

(cluck-cli-main (command-line-arguments))

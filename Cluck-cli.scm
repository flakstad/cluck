(import (chicken base)
        (chicken file)
        (chicken load)
        (chicken port)
        (chicken process-context))

(define (Cluck-cli-usage)
  (display "Usage: cluck [repl] [-i] [-e EXPR] [-l FILE] [FILE ...]") (newline)
  (display "  cluck                 start a Cluck REPL") (newline)
  (display "  cluck repl            start a Cluck REPL") (newline)
  (display "  cluck -e EXPR         evaluate one or more Cluck forms") (newline)
  (display "  cluck -l FILE         load a Cluck source file") (newline)
  (display "  cluck FILE ...        load one or more files") (newline)
  (display "  cluck -i ...          load/eval first, then enter the REPL") (newline))

(define (Cluck-cli-eval-form form)
  (call-with-values
   (lambda ()
     (eval form (interaction-environment)))
   Cluck-repl-print-results))

(define (Cluck-cli-eval-string expr)
  (call-with-input-string
   expr
   (lambda (port)
     (let loop ()
       (let ((form (read port)))
         (unless (eof-object? form)
           (Cluck-cli-eval-form form)
           (loop)))))))

(define (Cluck-cli-main args)
  (let loop ((xs args)
             (interactive? #f)
             (did-action? #f))
    (cond
      ((null? xs)
       (if (or interactive? (not did-action?))
           (Cluck-repl)
           (void)))
      ((or (string=? (car xs) "-h")
           (string=? (car xs) "--help"))
       (Cluck-cli-usage))
      ((or (string=? (car xs) "repl")
           (string=? (car xs) "--repl"))
       (Cluck-repl))
      ((or (string=? (car xs) "-i")
           (string=? (car xs) "--interactive"))
       (loop (cdr xs) #t did-action?))
      ((string=? (car xs) "-e")
       (if (pair? (cdr xs))
           (begin
             (Cluck-cli-eval-string (cadr xs))
             (loop (cddr xs) interactive? #t))
           (error "Cluck: -e expects an expression")))
      ((string=? (car xs) "-l")
       (if (pair? (cdr xs))
           (begin
             (load (cadr xs))
             (loop (cddr xs) interactive? #t))
           (error "Cluck: -l expects a file path")))
      (else
       (load (car xs))
       (loop (cdr xs) interactive? #t)))))

(load-relative "Cluck.scm")

(Cluck-cli-main (command-line-arguments))

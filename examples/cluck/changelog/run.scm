(import (chicken file)
        (chicken load)
        (chicken port)
        (chicken process-context))

(define (script-root)
  (let loop ((i (- (string-length (program-name)) 1)))
    (if (< i 0)
        (string-append (current-directory) "/")
        (if (char=? (string-ref (program-name) i) #\/)
            (substring (program-name) 0 (+ i 1))
            (loop (- i 1))))))

(let ((root (script-root)))
  (load (string-append root "../bootstrap.scm"))
  (let* ((project-root (cluck-bootstrap-root))
       (cluck-root (cluck-bootstrap-load-runtime! project-root)))
    (cluck-with-module-search-root
     cluck-root
     (lambda ()
       (cluck-bootstrap-load-app! project-root "examples/cluck/changelog/main.clk")
       (main (command-line-arguments))))))

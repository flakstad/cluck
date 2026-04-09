(import (chicken file)
        (chicken load)
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
    (handle-exceptions exn #t
      (create-directory (string-append project-root "build")))
    (cluck-with-module-search-root
     cluck-root
     (lambda ()
       (cluck-bootstrap-load-app! project-root "examples/cluck/ro/src/app.clk")
       (cluck-bootstrap-load-app! project-root "examples/cluck/ro/main.clk")
       ((ns-resolve 'cluck.examples.ro 'main)
        (command-line-arguments))))))

(import (chicken load)
        (chicken process-context))

(define (cluck-bootstrap-root)
  (let loop ((i (- (string-length (program-name)) 1)))
    (if (< i 0)
        (string-append (current-directory) "/")
        (if (char=? (string-ref (program-name) i) #\/)
            (substring (program-name) 0 (+ i 1))
            (loop (- i 1))))))

(define (cluck-bootstrap-load-runtime! root)
  (load (string-append root "cluck-init.scm")))

(define (cluck-bootstrap-load-app! root path)
  (load-file (string-append root path)))

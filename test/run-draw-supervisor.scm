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
  (handle-exceptions exn #t
    (create-directory (string-append root "../build")))
  (load (string-append root "../src/cluck-init.scm"))
  (load-file (string-append root "../examples/cluck/draw/dev.clk"))
  (load-file (string-append root "draw-supervisor.clk")))

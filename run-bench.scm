(import (chicken load)
        (chicken process-context))

(define (script-root)
  (let loop ((i (- (string-length (program-name)) 1)))
    (if (< i 0)
        (current-directory)
        (if (char=? (string-ref (program-name) i) #\/)
            (substring (program-name) 0 (+ i 1))
            (loop (- i 1))))))

(let ((root (script-root)))
  (load (string-append root "cluck-init.scm"))
  (load-file (string-append root "bench.clk")))

(bench-main (command-line-arguments))

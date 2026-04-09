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

(define (parse-int args default)
  (if (null? args)
      default
      (parse-long (car args))))

(define (parse-second-int args default)
  (if (or (null? args)
          (null? (cdr args)))
      default
      (parse-long (cadr args))))

(let ((root (script-root)))
  (handle-exceptions exn #t
    (create-directory (string-append root "../build")))
  (load (string-append root "../src/cluck-init.scm"))
  (load-file (string-append root "../examples/cluck/draw/dev.clk"))
  (load-file (string-append root "draw-brush-undo-script.clk"))
  (let ((args (command-line-arguments))
        (rounds 1)
        (pause 16))
    (set! rounds (parse-int args 1))
    (set! pause (parse-second-int args 16))
    (if (start-dev!)
      (begin
        (if (> rounds 1)
          (draw-replay-live-benchmark! (draw-brush-undo-script) rounds pause)
          (draw-replay-live! (draw-brush-undo-script) pause))
        (stop!))
      nil)))

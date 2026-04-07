(import (chicken base)
        (chicken file)
        (chicken process)
        (chicken process-context))

(define (normalize-directory dir)
  (if (and dir (> (string-length dir) 0))
      (if (char=? (string-ref dir (- (string-length dir) 1)) #\/)
          dir
          (string-append dir "/"))
      #f))

(define (parent-directory dir)
  (let* ((trimmed (if (and (> (string-length dir) 0)
                           (char=? (string-ref dir (- (string-length dir) 1)) #\/))
                      (substring dir 0 (- (string-length dir) 1))
                      dir))
         (len (string-length trimmed)))
    (let loop ((i (- len 1)))
      (cond
        ((< i 0) #f)
        ((char=? (string-ref trimmed i) #\/)
         (if (= i 0)
             "/"
             (substring trimmed 0 (+ i 1))))
        (else (loop (- i 1)))))))

(define (project-root)
  (let loop ((dir (normalize-directory (current-directory))))
    (cond
      ((file-exists? (string-append dir "examples/cluck/bootstrap.scm"))
       dir)
      ((string=? dir "/")
       (error "cannot locate examples/cluck/bootstrap.scm"))
      (else
       (let ((parent (parent-directory dir)))
         (if parent
             (loop parent)
             (error "cannot locate examples/cluck/bootstrap.scm")))))))

(define (shell-command root)
  (string-append
   "cd " root
   " && csc -v -O2 -strip "
   "-I/opt/homebrew/include "
   "-o build/draw examples/cluck/draw/run-standalone.scm "
   "-L/opt/homebrew/lib -rpath /opt/homebrew/lib -L -lSDL3"))

(let ((root (project-root)))
  (handle-exceptions exn #t
    (create-directory (string-append root "build")))
  (unless (zero? (system (shell-command root)))
    (error "SDL3 draw build failed"))
  (unless (zero? (system (string-append "cd " root " && ./build/draw")))
    (error "SDL3 draw binary exited with error")))

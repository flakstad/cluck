;; REPL-first development bootstrap for the SDL3 drawing example.
;;
;; Load this from a normal Cluck REPL after starting the project runtime:
;;
;;   (load-file "examples/cluck/draw/dev.scm")
;;
;; It compiles a loadable SDL3 extension on demand, loads it into the current
;; process, then loads the draw example and starts the background loop.

(load-file "examples/cluck/bootstrap.scm")

(import (chicken base)
        (chicken file)
        (chicken process))

(define (draw-dev-shell-quote text)
  (string-append "'" text "'"))

(define (draw-dev-root)
  (cluck-bootstrap-root))

(define (draw-dev-library-path root)
  (string-append root "build/dev/cluck-sdl3.so"))

(define (draw-dev-source-path root)
  (string-append root "cluck/sdl3.clk"))

(define (draw-dev-library-build-command root)
  (string-append
   "cd "
   (draw-dev-shell-quote root)
   " && "
   "csc -s -J -unit cluck.sdl3 "
   "-o "
   (draw-dev-shell-quote (draw-dev-library-path root))
   " "
   (draw-dev-shell-quote (draw-dev-source-path root))
   " $(pkg-config --cflags sdl3) $(pkg-config --libs sdl3)"))

(define (draw-dev-ensure-directory! path)
  (handle-exceptions exn #t
    (create-directory path)))

(define (draw-dev-ensure-library! root)
  (let ((lib (draw-dev-library-path root)))
    (unless (file-exists? lib)
      (draw-dev-ensure-directory! (string-append root "build/dev"))
      (unless (zero? (system (draw-dev-library-build-command root)))
        (error "SDL3 dev library build failed")))
    lib))

(let* ((root (draw-dev-root))
       (lib (draw-dev-ensure-library! root))
       (app (string-append root "examples/cluck/draw/main.clk")))
  (load-library 'cluck.sdl3 lib)
  (load-file app)
  (start-dev!))

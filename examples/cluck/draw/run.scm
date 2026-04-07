(import (chicken base)
        (chicken file)
        (chicken process)
        (chicken process-context))

(define sdl3-version "3.4.4")
(define sdl3-archive-url
  (string-append "https://github.com/libsdl-org/SDL/releases/download/release-"
                 sdl3-version
                 "/SDL3-"
                 sdl3-version
                 ".tar.gz"))

(define (shell-quote text)
  (string-append "'" text "'"))

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

(define (sdl3-vendor-dir root)
  (string-append root "build/vendor"))

(define (sdl3-archive-path root)
  (string-append (sdl3-vendor-dir root)
                 "/SDL3-"
                 sdl3-version
                 ".tar.gz"))

(define (sdl3-source-dir root)
  (string-append (sdl3-vendor-dir root)
                 "/SDL3-"
                 sdl3-version))

(define (sdl3-build-dir root)
  (string-append (sdl3-vendor-dir root)
                 "/SDL3-"
                 sdl3-version
                 "-build"))

(define (sdl3-install-dir root)
  (string-append (sdl3-vendor-dir root) "/sdl3-static"))

(define (sdl3-pkg-config-path root)
  (string-append (sdl3-install-dir root) "/lib/pkgconfig"))

(define (sdl3-lib-path root)
  (string-append (sdl3-install-dir root) "/lib/libSDL3.a"))

(define (ensure-directory! path)
  (handle-exceptions exn #t
    (create-directory path)))

(define (ensure-sdl3-static! root)
  (let ((lib (sdl3-lib-path root)))
    (unless (file-exists? lib)
      (let ((vendor-dir (sdl3-vendor-dir root))
            (archive (sdl3-archive-path root))
            (source-dir (sdl3-source-dir root))
            (build-dir (sdl3-build-dir root))
            (install-dir (sdl3-install-dir root)))
        (ensure-directory! vendor-dir)
        (unless (file-exists? archive)
          (unless (zero? (system (string-append "curl -L -o "
                                                (shell-quote archive)
                                                " "
                                                (shell-quote sdl3-archive-url))))
            (error "SDL3 download failed")))
        (unless (file-exists? source-dir)
          (unless (zero? (system (string-append "tar -xf "
                                                (shell-quote archive)
                                                " -C "
                                                (shell-quote vendor-dir))))
            (error "SDL3 extract failed")))
        (ensure-directory! install-dir)
        (unless (zero? (system (string-append
                                "cmake -S "
                                (shell-quote source-dir)
                                " -B "
                                (shell-quote build-dir)
                                " -DCMAKE_BUILD_TYPE=Release"
                                " -DSDL_SHARED=OFF"
                                " -DSDL_STATIC=ON"
                                " -DSDL_TESTS=OFF"
                                " -DSDL_EXAMPLES=OFF"
                                " -DCMAKE_INSTALL_PREFIX="
                                (shell-quote install-dir))))
          (error "SDL3 configure failed"))
        (unless (zero? (system (string-append
                                "cmake --build "
                                (shell-quote build-dir)
                                " --target install -j2")))
          (error "SDL3 build failed"))))
    lib))

(define (pkg-config-cflags root)
  (let ((pc-path (sdl3-pkg-config-path root)))
    (string-append
     "$(PKG_CONFIG_PATH="
     (shell-quote pc-path)
     " pkg-config --cflags sdl3)")))

(define (pkg-config-libs root)
  (let ((pc-path (sdl3-pkg-config-path root)))
    (string-append
     "$(PKG_CONFIG_PATH="
     (shell-quote pc-path)
     " pkg-config --libs --static sdl3)")))

(define (shell-command root)
  (string-append
   "cd "
   (shell-quote root)
   " && "
   "csc -static -deployed -k -v -O2 -strip "
   (pkg-config-cflags root)
   " -L \""
   (pkg-config-libs root)
   "\""
   " -o build/draw examples/cluck/draw/run-standalone.scm"))

(define (launcher-args)
  (command-line-arguments))

(define (run-command root)
  (let ((args (launcher-args)))
    (if (null? args)
        (string-append "cd " (shell-quote root) " && ./build/draw")
        (string-append
         "cd " (shell-quote root) " && ./build/draw "
         (apply string-append
                (map (lambda (arg)
                       (string-append (shell-quote arg) " "))
                     args))))))

(let ((root (project-root)))
  (handle-exceptions exn #t
    (create-directory (string-append root "build")))
  (ensure-sdl3-static! root)
  (unless (zero? (system (shell-command root)))
    (error "SDL3 draw build failed"))
  (unless (zero? (system (run-command root)))
    (error "SDL3 draw binary exited with error")))

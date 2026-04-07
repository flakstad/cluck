(import (chicken file)
        (chicken load)
        (chicken process-context))

(define (cluck-template-trim-trailing-slash path)
  (let ((len (string-length path)))
    (if (and (> len 0)
             (char=? (string-ref path (- len 1)) #\/))
        (substring path 0 (- len 1))
        path)))

(define (cluck-template-normalize-directory dir)
  (if (and dir (> (string-length dir) 0))
      (let ((len (string-length dir)))
        (if (char=? (string-ref dir (- len 1)) #\/)
            dir
            (string-append dir "/")))
      #f))

(define (cluck-template-absolute-directory dir)
  (cond
    ((not dir) #f)
    ((and (> (string-length dir) 0)
          (char=? (string-ref dir 0) #\/))
     (cluck-template-normalize-directory dir))
    (else
     (let ((cwd (cluck-template-normalize-directory (current-directory))))
       (and cwd
            (string-append cwd (cluck-template-trim-trailing-slash dir) "/"))))))

(define (cluck-template-executable-root)
  (cluck-template-absolute-directory
   (let loop ((i (- (string-length (program-name)) 1)))
     (if (< i 0)
         (current-directory)
         (if (char=? (string-ref (program-name) i) #\/)
             (substring (program-name) 0 (+ i 1))
             (loop (- i 1)))))))

(define (cluck-template-parent-directory dir)
  (let* ((trimmed (cluck-template-trim-trailing-slash dir))
         (len (string-length trimmed)))
    (let loop ((i (- len 1)))
      (cond
        ((< i 0) #f)
        ((char=? (string-ref trimmed i) #\/)
         (if (= i 0)
             "/"
             (substring trimmed 0 (+ i 1))))
        (else (loop (- i 1)))))))

(define (cluck-template-project-root start)
  (let loop ((dir (cluck-template-normalize-directory start)))
    (cond
      ((not dir) #f)
      ((file-exists? (string-append dir "src/app/main.clk")) dir)
      ((string=? dir "/") #f)
      (else
       (let ((parent (cluck-template-parent-directory dir)))
         (and parent (loop parent)))))))

(define (cluck-template-root)
  (or (cluck-template-project-root (cluck-template-executable-root))
      (cluck-template-normalize-directory (current-directory))))

(define (cluck-template-absolute-path root path)
  (if (and path
           (> (string-length path) 0)
           (char=? (string-ref path 0) #\/))
      path
      (string-append (cluck-template-trim-trailing-slash root) "/" path)))

(define (cluck-template-cluck-root root)
  (or (let ((home (get-environment-variable "CLUCK_HOME")))
        (cluck-template-normalize-directory home))
      (let ((vendor (string-append (cluck-template-trim-trailing-slash root)
                                   "/vendor/cluck/")))
        (and (file-exists? (string-append vendor "src/cluck-init.scm"))
             vendor))
      (let ((local (string-append (cluck-template-trim-trailing-slash root)
                                  "/cluck/")))
        (and (file-exists? (string-append local "src/cluck-init.scm"))
             local))
      (cluck-template-normalize-directory root)))

(define (cluck-template-load-runtime! root)
  (let ((cluck-root (cluck-template-cluck-root root)))
    (dynamic-wind
      (lambda ()
        (change-directory cluck-root))
      (lambda ()
        (load "src/cluck.scm"))
      (lambda ()
        (change-directory root)))
    cluck-root))

(define (cluck-template-load-app! root path)
  (cluck-with-module-search-root
   root
   (lambda ()
     (cluck-with-directory
      root
      (lambda ()
        (load (cluck-template-absolute-path root path))
        (void))))))

(define (cluck-template-port->string port)
  (let loop ((chars '()))
    (let ((ch (read-char port)))
      (if (eof-object? ch)
          (list->string (reverse chars))
          (loop (cons ch chars))))))

(define (cluck-template-file->string root path)
  (call-with-input-file (cluck-template-absolute-path root path)
                        cluck-template-port->string))

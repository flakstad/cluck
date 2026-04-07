(import (chicken file)
        (prefix (chicken file posix) posix:)
        (chicken load)
        (chicken port)
        (chicken process-context))

(define (cluck-bootstrap-trim-trailing-slash path)
  (let ((len (string-length path)))
    (if (and (> len 0)
             (char=? (string-ref path (- len 1)) #\/))
        (substring path 0 (- len 1))
        path)))

(define (cluck-bootstrap-normalize-directory dir)
  (if (and dir (> (string-length dir) 0))
      (let ((len (string-length dir)))
        (if (char=? (string-ref dir (- len 1)) #\/)
            dir
            (string-append dir "/")))
      #f))

(define (cluck-bootstrap-executable-root)
  (let loop ((i (- (string-length (program-name)) 1)))
    (if (< i 0)
        (string-append (current-directory) "/")
        (if (char=? (string-ref (program-name) i) #\/)
            (substring (program-name) 0 (+ i 1))
            (loop (- i 1))))))

(define (cluck-bootstrap-parent-directory dir)
  (let* ((trimmed (cluck-bootstrap-trim-trailing-slash dir))
         (len (string-length trimmed)))
    (let loop ((i (- len 1)))
      (cond
        ((< i 0) #f)
        ((char=? (string-ref trimmed i) #\/)
         (if (= i 0)
             "/"
             (substring trimmed 0 (+ i 1))))
        (else (loop (- i 1)))))))

(define (cluck-bootstrap-project-root start)
  (let loop ((dir (cluck-bootstrap-normalize-directory start)))
    (cond
      ((not dir) #f)
      ((or (file-exists? (string-append dir "src/cluck.scm"))
           (file-exists? (string-append dir "src/cluck-cli.scm")))
       dir)
      ((string=? dir "/") #f)
      (else
       (let ((parent (cluck-bootstrap-parent-directory dir)))
         (and parent (loop parent)))))))

(define (cluck-bootstrap-root)
  (or (cluck-bootstrap-project-root (cluck-bootstrap-executable-root))
      (cluck-bootstrap-normalize-directory (current-directory))))

(define (cluck-bootstrap-cluck-root root)
  (or (let ((home (get-environment-variable "CLUCK_HOME")))
        (cluck-bootstrap-normalize-directory home))
      (let ((vendor (string-append (cluck-bootstrap-trim-trailing-slash root)
                                   "/vendor/cluck/")))
        (and (file-exists? (string-append vendor "src/cluck-init.scm"))
             vendor))
      (let ((local (string-append (cluck-bootstrap-trim-trailing-slash root)
                                  "/cluck/")))
        (and (file-exists? (string-append local "src/cluck-init.scm"))
             local))
      (cluck-bootstrap-normalize-directory root)))

(define (cluck-bootstrap-load-runtime! root)
  (let ((cluck-root (cluck-bootstrap-cluck-root root)))
    (dynamic-wind
      (lambda ()
        (change-directory cluck-root))
      (lambda ()
        (load "src/cluck.scm"))
      (lambda ()
        (change-directory root)))
    cluck-root))

(define (cluck-bootstrap-load-app! root path)
  (load-file (cluck-bootstrap-absolute-path root path)))

(define (cluck-bootstrap-absolute-path root path)
  (if (and path
           (> (string-length path) 0)
           (char=? (string-ref path 0) #\/))
      path
      (string-append (cluck-bootstrap-trim-trailing-slash root) "/" path)))

(define (cluck-bootstrap-port->string port)
  (let loop ((chars '()))
    (let ((ch (read-char port)))
      (if (eof-object? ch)
          (list->string (reverse chars))
          (loop (cons ch chars))))))

(define (cluck-bootstrap-file->string path)
  (call-with-input-file path cluck-bootstrap-port->string))

(define (cluck-bootstrap-directory-files path)
  (let loop ((entries (directory path))
             (out '()))
    (if (null? entries)
        out
        (let* ((entry (car entries))
               (child (string-append (cluck-bootstrap-trim-trailing-slash path)
                                     "/"
                                     entry))
               (next (cond
                       ((posix:directory? child)
                        (cluck-bootstrap-directory-files child))
                       ((file-exists? child)
                        (list child))
                       (else '()))))
          (loop (cdr entries) (append out next))))))

(define (cluck-bootstrap-expand-target root target)
  (let ((path (cluck-bootstrap-absolute-path root target)))
    (cond
      ((posix:directory? path) (cluck-bootstrap-directory-files path))
      ((file-exists? path) (list path))
      (else (error "Path does not exist" path)))))

(define (cluck-bootstrap-expand-targets root targets)
  (let loop ((items targets)
             (out '()))
    (if (null? items)
        out
        (loop (cdr items)
              (append out (cluck-bootstrap-expand-target root (car items)))))))

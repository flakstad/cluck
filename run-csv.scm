(import scheme
        (chicken base)
        (chicken load)
        (chicken process-context))

(load "cluck-bootstrap.scm")

(define (csv-runner-option? arg)
  (and (> (string-length arg) 0)
       (char=? (string-ref arg 0) #\-)))

(define (csv-runner-suffix? path suffix)
  (let* ((path-len (string-length path))
         (suffix-len (string-length suffix)))
    (and (>= path-len suffix-len)
         (string=? (substring path (- path-len suffix-len) path-len)
                   suffix))))

(define (csv-runner-default-separator source)
  (if (or (csv-runner-suffix? source ".tsv")
          (csv-runner-suffix? source ".TSV"))
      "\t"
      ","))

(define (csv-runner-parse-args args)
  (let loop ((rest args) (separator #f) (header? #t) (source #f))
    (cond
      ((null? rest)
       (list separator header? source))
     ((string=? (car rest) "--tsv")
       (loop (cdr rest) "\t" header? source))
     ((string=? (car rest) "--csv")
       (loop (cdr rest) "," header? source))
      ((string=? (car rest) "--no-header")
       (loop (cdr rest) separator #f source))
      ((string=? (car rest) "--header")
       (loop (cdr rest) separator #t source))
      ((csv-runner-option? (car rest))
       (error "Usage: run-csv.scm [--csv|--tsv] [--header|--no-header] [file]"))
      ((not source)
       (loop (cdr rest) separator header? (car rest)))
      (else
       (error "Usage: run-csv.scm [--csv|--tsv] [--header|--no-header] [file]")))))

(let* ((project-root (cluck-bootstrap-root))
       (cluck-root (cluck-bootstrap-load-runtime! project-root)))
  (cluck-bootstrap-load-app! project-root "examples/cluck/csv.clk")
  (let* ((args (command-line-arguments))
         (parsed (csv-runner-parse-args args))
         (source (caddr parsed))
         (stdin? (or (not source)
                     (string=? source "-")))
         (separator (or (car parsed)
                        (if (and source (not stdin?))
                            (csv-runner-default-separator source)
                            ",")))
         (header? (cadr parsed))
         (source-name (if stdin?
                        "stdin"
                        source))
         (text (if stdin?
                 (cluck-bootstrap-port->string (current-input-port))
                 (cluck-bootstrap-file->string
                  (cluck-bootstrap-absolute-path project-root source)))))
    (main source-name text separator header?)))

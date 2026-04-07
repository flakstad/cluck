(import scheme
        (chicken base)
        (chicken io)
        (chicken port)
        (chicken read-syntax)
        srfi-69)

(define cluck-nil (list 'cluck-nil))
(define nil cluck-nil)
(define true #t)
(define false #f)

(define-record-type cluck-keyword
  (make-cluck-keyword namespace name)
  cluck-keyword?
  (namespace keyword-namespace)
  (name keyword-name))

(define-record-type cluck-map
  (make-cluck-map table)
  cluck-map?
  (table map-hash))

(define-record-type cluck-set
  (make-cluck-set table)
  cluck-set?
  (table set-hash))

(define (cluck-delimiter-char? c)
  (or (char-whitespace? c)
      (memv c '(#\( #\) #\[ #\] #\{ #\} #\" #\; #\, #\'))))

(define (cluck-string-index-char s needle)
  (let loop ((i 0))
    (cond
      ((= i (string-length s)) #f)
      ((char=? (string-ref s i) needle) i)
      (else (loop (+ i 1))))))

(define (cluck-split-qualified-name s)
  (let ((slash (cluck-string-index-char s #\/)))
    (if slash
        (cons (substring s 0 slash)
              (substring s (+ slash 1) (string-length s)))
        (cons #f s))))

(define (keyword? x)
  (cluck-keyword? x))

(define (map? x)
  (cluck-map? x))

(define (set? x)
  (cluck-set? x))

(define (nil? x)
  (eq? x nil))

(define (false? x)
  (eq? x false))

(define (truthy? x)
  (if (false? x)
      #f
      (if (nil? x) #f #t)))

(define (cluck-make-keyword namespace name)
  (make-cluck-keyword namespace name))

(define (cluck-object->string x)
  (cond
    ((string? x) x)
    ((symbol? x) (symbol->string x))
    ((keyword? x) (keyword-name x))
    ((number? x) (number->string x))
    ((boolean? x) (if x "true" "false"))
    ((nil? x) "nil")
    (else
     (let ((p (open-output-string)))
       (write x p)
       (get-output-string p)))))

(define (keyword . args)
  (cond
    ((null? args)
     (error "keyword expects one or two arguments"))
    ((null? (cdr args))
     (let ((x (car args)))
       (cond
         ((keyword? x) x)
         ((symbol? x)
          (let* ((parts (cluck-split-qualified-name (symbol->string x))))
            (cluck-make-keyword (car parts) (cdr parts))))
         ((string? x)
          (let* ((parts (cluck-split-qualified-name x)))
            (cluck-make-keyword (car parts) (cdr parts))))
         (else
          (cluck-make-keyword #f (cluck-object->string x))))))
    ((null? (cddr args))
     (cluck-make-keyword
      (let ((ns (car args)))
        (if (or (eq? ns #f) (eq? ns nil)) #f (cluck-object->string ns)))
      (let ((name (cadr args)))
        (cluck-object->string name))))
    (else
     (error "keyword expects one or two arguments"))))

(define (name x)
  (cond
    ((keyword? x) (keyword-name x))
    ((symbol? x) (cdr (cluck-split-qualified-name (symbol->string x))))
    ((string? x) x)
    (else (error "name expects a keyword, symbol, or string" x))))

(define (namespace x)
  (cond
    ((keyword? x) (keyword-namespace x))
    ((symbol? x) (car (cluck-split-qualified-name (symbol->string x))))
    ((string? x) (car (cluck-split-qualified-name x)))
    (else #f)))

(define (cluck-make-map)
  (make-cluck-map (make-hash-table)))

(define (cluck-make-set)
  (make-cluck-set (make-hash-table)))

(define (cluck-ensure-even-list items who)
  (let loop ((xs items))
    (cond
      ((null? xs) #t)
      ((null? (cdr xs))
       (error who "expects an even number of forms"))
      (else (loop (cddr xs))))))

(define (hash-map . kvs)
  (let ((m (cluck-make-map)))
    (cluck-ensure-even-list kvs 'hash-map)
    (let loop ((xs kvs))
      (if (null? xs)
          m
          (begin
            (hash-table-set! (map-hash m) (car xs) (cadr xs))
            (loop (cddr xs)))))))

(define (set . xs)
  (let ((s (cluck-make-set)))
    (let loop ((items xs))
      (if (null? items)
          s
          (begin
            (hash-table-set! (set-hash s) (car items) #t)
            (loop (cdr items)))))))

(define hash-set set)

(define (cluck-normalize-vector v)
  (let* ((len (vector-length v))
         (out (make-vector len)))
    (let loop ((i 0))
      (if (= i len)
          out
          (begin
            (vector-set! out i (normalize-edn (vector-ref v i)))
            (loop (+ i 1)))))))

(define (cluck-normalize-list x)
  (cond
    ((null? x) '())
    ((pair? x)
     (cons (normalize-edn (car x))
           (cluck-normalize-list (cdr x))))
    (else (normalize-edn x))))

(define (cluck-normalize-map m)
  (let ((out (cluck-make-map)))
    (hash-table-for-each
     (map-hash m)
     (lambda (k v)
       (hash-table-set! (map-hash out)
                        (normalize-edn k)
                        (normalize-edn v))))
    out))

(define (cluck-normalize-set s)
  (let ((out (cluck-make-set)))
    (hash-table-for-each
     (set-hash s)
     (lambda (k v)
       (hash-table-set! (set-hash out)
                        (normalize-edn k)
                        #t)))
    out))

(define (normalize-edn x)
  (cond
    ((keyword? x) x)
    ((map? x) (cluck-normalize-map x))
    ((set? x) (cluck-normalize-set x))
    ((vector? x) (cluck-normalize-vector x))
    ((symbol? x)
     (cond
       ((eq? x 'nil) nil)
       ((eq? x 'true) true)
       ((eq? x 'false) false)
       (else x)))
    ((pair? x) (cluck-normalize-list x))
    (else x)))

(define (cluck-string-input-port? port)
  (let ((name (port-name port)))
    (and (string? name)
         (string=? name "(string)"))))

(define (cluck-source-form x)
  (cond
    ((keyword? x)
     (let ((ns (keyword-namespace x))
           (nm (keyword-name x)))
       (if ns
           `(keyword ,(string-append ns "/" nm))
           `(keyword ,nm))))
    ((map? x)
     (let ((pairs '()))
       (hash-table-for-each
        (map-hash x)
        (lambda (k v)
          (set! pairs
                (cons (cluck-source-form v)
                      (cons (cluck-source-form k) pairs)))))
       `(hash-map ,@(reverse pairs))))
    ((set? x)
     (let ((items '()))
       (hash-table-for-each
        (set-hash x)
        (lambda (k v)
          (set! items (cons (cluck-source-form k) items))))
       `(set ,@(reverse items))))
    ((vector? x)
     (let loop ((i 0) (items '()))
       (if (= i (vector-length x))
           `(vector ,@(reverse items))
           (loop (+ i 1)
                 (cons (cluck-source-form (vector-ref x i)) items)))))
    ((pair? x)
     (cons (cluck-source-form (car x))
           (cluck-source-form (cdr x))))
    (else x)))

(define (edn-clean-string s)
  (let* ((len (string-length s))
         (out (open-output-string)))
    (letrec ((emit
              (lambda (c)
                (write-char c out)))
             (scan-normal
              (lambda (i)
                (if (>= i len)
                    (get-output-string out)
                    (let ((c (string-ref s i)))
                      (cond
                        ((char=? c #\,)
                         (emit #\space)
                         (scan-normal (+ i 1)))
                        ((char=? c #\;)
                         (emit #\space)
                         (scan-comment (+ i 1)))
                        ((char=? c #\")
                         (emit c)
                         (scan-string (+ i 1)))
                        (else
                         (emit c)
                         (scan-normal (+ i 1))))))))
             (scan-string
              (lambda (i)
                (if (>= i len)
                    (error "unexpected EOF in string literal")
                    (let ((c (string-ref s i)))
                      (emit c)
                      (cond
                        ((char=? c #\\)
                         (if (>= (+ i 1) len)
                             (error "unexpected EOF in string escape")
                             (begin
                               (emit (string-ref s (+ i 1)))
                               (scan-string (+ i 2)))))
                        ((char=? c #\")
                         (scan-normal (+ i 1)))
                        (else
                         (scan-string (+ i 1))))))))
             (scan-comment
              (lambda (i)
                (if (>= i len)
                    (get-output-string out)
                    (let ((c (string-ref s i)))
                      (if (char=? c #\newline)
                          (scan-normal i)
                          (scan-comment (+ i 1))))))))
      (scan-normal 0))))

(define (cluck-read-forms s)
  (call-with-input-string
   (edn-clean-string s)
   (lambda (p)
     (let loop ((forms (read-list p)) (acc '()))
       (if (null? forms)
           (reverse acc)
           (loop (cdr forms)
                 (cons (normalize-edn (car forms)) acc)))))))

(define (cluck-read-one s)
  (call-with-input-string
   (edn-clean-string s)
   (lambda (p)
     (normalize-edn (read p)))))

(define (cluck-read-balanced-content port close-char)
  (let ((out (open-output-string))
        (stack (list close-char)))
    (define (emit c)
      (write-char c out))
    (define (top)
      (car stack))
    (define (push! c)
      (set! stack (cons c stack)))
    (define (pop!)
      (set! stack (cdr stack)))
    (letrec ((scan
              (lambda (state)
                (let ((c (read-char port)))
                  (cond
                    ((eof-object? c)
                     (error "unexpected EOF while reading literal"))
                    ((eq? state 'string)
                     (emit c)
                     (cond
                       ((char=? c #\\)
                        (let ((d (read-char port)))
                          (if (eof-object? d)
                              (error "unexpected EOF in string escape")
                              (begin
                                (emit d)
                                (scan 'string)))))
                       ((char=? c #\")
                        (scan 'normal))
                       (else
                        (scan 'string))))
                    ((eq? state 'comment)
                     (if (char=? c #\newline)
                         (scan 'normal)
                         (scan 'comment)))
                    ((char=? c #\")
                     (emit c)
                     (scan 'string))
                    ((char=? c #\;)
                     (scan 'comment))
                    ((char=? c #\#)
                     (let ((n (peek-char port)))
                       (cond
                         ((eof-object? n)
                          (emit c)
                          (scan 'normal))
                         ((char=? n #\{)
                          (emit c)
                          (emit (read-char port))
                          (push! #\})
                          (scan 'normal))
                         ((char=? n #\[)
                          (emit c)
                          (emit (read-char port))
                          (push! #\])
                          (scan 'normal))
                         ((char=? n #\()
                          (emit c)
                          (emit (read-char port))
                          (push! #\))
                          (scan 'normal))
                         (else
                          (emit c)
                          (scan 'normal)))))
                    ((char=? c #\()
                     (emit c)
                     (push! #\))
                     (scan 'normal))
                    ((char=? c #\[)
                     (emit c)
                     (push! #\])
                     (scan 'normal))
                    ((char=? c #\{)
                     (emit c)
                     (push! #\})
                     (scan 'normal))
                    ((char=? c (top))
                     (pop!)
                     (if (null? stack)
                         (get-output-string out)
                         (begin
                           (emit c)
                           (scan 'normal))))
                    ((memv c '(#\) #\] #\}))
                     (error "unexpected closing delimiter" c))
                    (else
                     (emit c)
                     (scan 'normal)))))))
      (scan 'normal))))

(define (read-keyword port)
  (let ((token (read-token
                (lambda (c)
                  (if (cluck-delimiter-char? c) #f #t))
                port)))
    (if token
        (if (string=? token "")
            (error "empty keyword literal")
            (let* ((normalized (if (and (> (string-length token) 0)
                                        (char=? (string-ref token 0) #\:))
                                   (substring token 1 (string-length token))
                                   token))
                   (parts (cluck-split-qualified-name normalized)))
              (if (cluck-string-input-port? port)
                  (keyword (car parts) (cdr parts))
                  `(keyword ,normalized))))
        (error "empty keyword literal"))))

(define (read-vector-literal port)
  (let ((items (cluck-read-forms (cluck-read-balanced-content port #\]))))
    (if (cluck-string-input-port? port)
        (list->vector items)
        (cons 'vector (map cluck-source-form items)))))

(define (read-map-literal port)
  (let ((items (cluck-read-forms (cluck-read-balanced-content port #\}))))
    (cluck-ensure-even-list items 'read-map-literal)
    (if (cluck-string-input-port? port)
        (let ((m (cluck-make-map)))
          (let loop ((xs items))
            (if (null? xs)
                m
                (begin
                  (hash-table-set! (map-hash m) (car xs) (cadr xs))
                  (loop (cddr xs))))))
        (let loop ((xs items) (acc '()))
          (if (null? xs)
              (cons 'hash-map acc)
              (loop (cddr xs)
                    (append acc
                            (list (cluck-source-form (car xs))
                                  (cluck-source-form (cadr xs))))))))))

(define (read-set-literal port)
  (let ((items (cluck-read-forms (cluck-read-balanced-content port #\}))))
    (if (cluck-string-input-port? port)
        (let ((s (cluck-make-set)))
          (let loop ((xs items))
            (if (null? xs)
                s
                (begin
                  (hash-table-set! (set-hash s) (car xs) #t)
                  (loop (cdr xs))))))
        (cons 'set (map cluck-source-form items)))))

(define (read-discard port)
  (read port)
  (values))

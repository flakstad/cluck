(import (chicken load)
        (prefix http-client http:)
        (prefix json json:)
        (prefix uri-common uri:))

;; Bootstrap for the weather example.
;;
;; This file handles the CHICKEN-only pieces and loads the Cluck runtime before
;; the actual app source is evaluated.

(load-relative "cluck-init.scm")

(define (weather-json-null? x)
  (eq? x (void)))

(define (weather-json->cluck x)
  (if (weather-json-null? x)
      nil
      (if (vector? x)
          (reduce (lambda (result entry)
                    (assoc result
                           (keyword (car entry))
                           (weather-json->cluck (cdr entry))))
                  (hash-map)
                  (seq x))
          (if (or (pair? x) (null? x))
              (mapv weather-json->cluck x)
              x))))

(define (weather-fetch-json url)
  (http:with-input-from-request
   url
   #f
   (lambda ()
     (weather-json->cluck (json:json-read)))))

(define (weather-url location)
  (string-append "http://wttr.in/"
                 (uri:uri-encode-string location)
                 "?format=j1"))

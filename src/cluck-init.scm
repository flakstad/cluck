(import (chicken load))

;; Load the language layer without starting a nested REPL.
(load-relative "cluck.scm")

;; Keep the convenient top-level alias in the interactive source path.
(define read-string cluck-core-read-string)
(cluck-intern! (current-ns) 'read-string read-string)
(cluck-put-doc! (current-ns) 'read-string "Read one Cluck form from STRING.")

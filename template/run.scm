(import (chicken load)
        (chicken process-context))

(include "bootstrap.scm")

(let* ((project-root (cluck-template-root))
       (cluck-root (cluck-template-load-runtime! project-root)))
  (cluck-with-module-search-root
   cluck-root
   (lambda ()
     (cluck-template-load-app! project-root "src/app/main.clk"))))

(main (command-line-arguments))

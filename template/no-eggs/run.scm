(import (chicken file)
        (chicken load)
        (chicken port)
        (chicken process-context))

(include "bootstrap.scm")

(let* ((project-root (cluck-template-root))
       (cluck-root (cluck-template-load-runtime! project-root)))
  (cluck-with-module-search-root
   cluck-root
   (lambda ()
     (cluck-template-load-app! project-root "src/app/main.clk")
     (let ((args (command-line-arguments)))
       (cond
         ((null? args)
          (main "stdin" (cluck-template-port->string (current-input-port))))
         ((= (length args) 1)
          (let ((path (car args)))
            (main path (cluck-template-file->string project-root path))))
         (else
          (error "Usage: run.scm [file]")))))))

(import (chicken file)
        (chicken load)
        (chicken port)
        (chicken process-context))

(load "cluck-bootstrap.scm")

(let* ((project-root (cluck-bootstrap-root))
       (cluck-root (cluck-bootstrap-load-runtime! project-root)))
  (cluck-with-module-search-root
   cluck-root
   (lambda ()
     (cluck-bootstrap-load-app! project-root "examples/cluck/text-report.clk")
     (let ((args (command-line-arguments)))
       (cond
         ((null? args)
          (main "stdin" (cluck-bootstrap-port->string (current-input-port))))
         ((= (length args) 1)
          (let ((path (car args)))
            (main path (cluck-bootstrap-file->string (cluck-bootstrap-absolute-path project-root path)))))
         (else
          (error "Usage: run-text-report.scm [file]")))))))

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
     (cluck-bootstrap-load-app! project-root "examples/cluck/changelog.clk")
     (main (command-line-arguments)))))

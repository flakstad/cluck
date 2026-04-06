(import (chicken load)
        (chicken process-context))

(load-relative "Cluck-init.scm")
(load-relative "bench.clj")

(bench-main (command-line-arguments))

(import (chicken load)
        (chicken process-context))

(load-relative "scm-clj-init.scm")
(load-relative "bench.clj.scm")

(bench-main (command-line-arguments))

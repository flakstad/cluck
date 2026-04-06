(import (chicken load)
        (chicken process-context))

(load-relative "scm-clj-init.scm")
(load-relative "scm-clj/app.clj.scm")

(println (report (read-string "[1 2 3 4]")))

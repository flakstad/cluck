(import (chicken load)
        (chicken process-context))

(load-relative "Cluck-init.scm")
(load-relative "Cluck/app.clj.scm")

(println (report (read-string "[1 2 3 4]")))

(import (chicken load)
        (chicken process-context))

(load-relative "cluck-init.scm")
(load-relative "cluck/app.clk")

(println (report (read-string "[1 2 3 4]")))

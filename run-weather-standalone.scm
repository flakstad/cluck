(import (chicken load))

;; Development helper: load the standalone weather source in a REPL or `csi`
;; session. This is packaging support, not the canonical Cluck weather app.
(load-relative "cluck/weather-standalone.clk")

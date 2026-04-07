(import (chicken load))

;; Development helper: load the standalone weather source in a REPL or `csi`
;; session. The standalone source itself already calls `main`.
(load-relative "cluck/weather-standalone.clk")

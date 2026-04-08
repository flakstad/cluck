;; Plain Scheme extension for the Cluck project report demo.
;;
;; This file is loaded with `load-file` from the Cluck example app. It
;; registers a hook that adds an attention note and focus items to the report
;; model.

(register-report-hook!
 add-focus-items!)

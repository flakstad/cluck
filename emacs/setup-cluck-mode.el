(defvar cluck-mode-map (make-sparse-keymap)
  "Keymap for `cluck-mode'.")

(with-eval-after-load 'clojure-mode
  (define-derived-mode cluck-mode clojure-mode "Cluck"
    "Major mode for editing Cluck source files."
    (setq-local clojure-align-forms-automatically nil)
    (setq-local clojure-indent-style 'align-arguments))

  (add-to-list 'auto-mode-alist '("\\.clk\\'" . cluck-mode))

  (add-hook 'cluck-mode-hook #'yas-minor-mode)
  (add-hook 'cluck-mode-hook #'hs-minor-mode)
  (add-hook 'cluck-mode-hook #'flycheck-mode)
  (add-hook 'cluck-mode-hook #'paredit-mode))

(provide 'setup-cluck-mode)

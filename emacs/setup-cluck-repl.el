(require 'comint)
(require 'xref)

(defgroup cluck nil
  "Editing and REPL support for Cluck."
  :group 'languages)

(defcustom cluck-repl-buffer-name "*Cluck*"
  "Buffer name used for the Cluck REPL."
  :type 'string
  :group 'cluck)

(defcustom cluck-doc-buffer-name "*Cluck Doc*"
  "Buffer name used for Cluck doc output."
  :type 'string
  :group 'cluck)

(defcustom cluck-inline-result-prefix "=> "
  "Prefix used for inline evaluation overlays."
  :type 'string
  :group 'cluck)

(defcustom cluck-fallback-executable "cluck"
  "Fallback executable used when no local Cluck checkout is found."
  :type 'string
  :group 'cluck)

(defcustom cluck-draw-bootstrap-timeout 60.0
  "Seconds to wait while loading the SDL3 draw dev bootstrap."
  :type 'number
  :group 'cluck)

(defvar cluck--last-source-buffer nil)

(defun cluck-clear-inline-results ()
  "Delete Cluck inline result overlays in the current buffer."
  (remove-overlays (point-min) (point-max) 'cluck-result-overlay t))

(defun cluck--enable-inline-result-clearing ()
  "Clear Cluck overlays before the next command in this buffer."
  (add-hook 'pre-command-hook #'cluck-clear-inline-results nil t))

(defun cluck--project-root (&optional start)
  "Return the nearest Cluck project root for START or the current buffer."
  (let* ((path (cond
                ((bufferp start) (or (buffer-file-name start) default-directory))
                ((stringp start) start)
                ((buffer-file-name) (buffer-file-name))
                (t default-directory)))
         (dir (if (and path (file-directory-p path))
                  path
                (file-name-directory (expand-file-name path)))))
    (or (locate-dominating-file dir "src/cluck-cli.scm")
        (locate-dominating-file dir "src/cluck.scm")
        (locate-dominating-file dir ".git")
        dir)))

(defun cluck--draw-source-p (&optional start)
  "Return non-nil when START points at the draw example."
  (let ((path (cond
               ((bufferp start) (or (buffer-file-name start) default-directory))
               ((stringp start) start)
               ((buffer-file-name) (buffer-file-name))
               (t default-directory))))
    (and path
         (string-match-p "/examples/cluck/draw/" path))))

(defun cluck--draw-dev-bootstrap-path (&optional start)
  "Return the absolute path to the draw development bootstrap."
  (expand-file-name "examples/cluck/draw/dev.clk"
                    (file-name-as-directory (cluck--project-root start))))

(defun cluck--repl-command (&optional start)
  "Return the command list used to launch a Cluck REPL."
  (let* ((root (file-name-as-directory (cluck--project-root start)))
         (native (expand-file-name "build/cluck" root))
         (launcher (expand-file-name "src/cluck-cli.scm" root))
         (fallback (executable-find cluck-fallback-executable)))
    (cond
     ((file-readable-p launcher)
      (list "csi" "-q" "-s" launcher))
     ((file-executable-p native)
      (list native))
     (fallback
      (list fallback))
     (t
      (error "Could not find a Cluck REPL launcher")))))

(defun cluck--prompt-present-p (buffer)
  "Return non-nil if BUFFER already shows a Cluck prompt."
  (with-current-buffer buffer
    (save-excursion
      (goto-char (point-max))
      (re-search-backward comint-prompt-regexp nil t))))

(defun cluck--wait-for-prompt (buffer &optional timeout)
  "Wait until BUFFER shows a prompt, or signal an error after TIMEOUT seconds."
  (let* ((process (get-buffer-process buffer))
         (deadline (+ (float-time) (or timeout 10.0))))
    (while (and process
                (not (cluck--prompt-present-p buffer))
                (< (float-time) deadline))
      (accept-process-output process 0.1))
    (unless (cluck--prompt-present-p buffer)
      (error "Timed out waiting for Cluck REPL prompt"))))

(define-derived-mode cluck-repl-mode comint-mode "Cluck"
  "Major mode for the Cluck REPL."
  (setq-local comint-prompt-regexp "^cluck> ")
  (setq-local comint-use-prompt-regexp t)
  (setq-local comint-process-echoes nil)
  (setq-local comint-scroll-to-bottom-on-input t)
  (setq-local comint-scroll-to-bottom-on-output t)
  (setq-local truncate-lines t))

(defun cluck--ensure-repl-buffer (&optional start)
  "Return a live Cluck REPL buffer, starting one if needed."
  (let* ((root (file-name-as-directory (cluck--project-root start)))
         (default-directory root)
         (buffer (get-buffer-create cluck-repl-buffer-name)))
    (unless (comint-check-proc buffer)
      (let* ((command (cluck--repl-command start))
             (program (car command))
             (args (cdr command)))
        (apply #'make-comint-in-buffer "cluck" buffer program nil args)
        (with-current-buffer buffer
          (cluck-repl-mode)
          (setq-local default-directory root)
          (let ((process (get-buffer-process buffer)))
            (when process
              (set-process-query-on-exit-flag process nil))))))
    (cluck--wait-for-prompt buffer)
    buffer))

(defun cluck-repl ()
  "Pop to the Cluck REPL, starting it if necessary."
  (interactive)
  (pop-to-buffer (cluck--ensure-repl-buffer)))

(defun cluck-draw-repl ()
  "Pop to the Cluck draw REPL, starting the generic REPL and loading the draw bootstrap."
  (interactive)
  (let* ((buffer (cluck--ensure-repl-buffer))
         (output (cluck--send-string
                  (cluck--load-file-command (cluck--draw-dev-bootstrap-path))
                  nil
                  cluck-draw-bootstrap-timeout)))
    (pop-to-buffer buffer)
    (cluck--show-echo-output output "Cluck draw dev bootstrap loaded")))

(defun cluck-switch-to-repl ()
  "Pop to the context-appropriate Cluck REPL."
  (interactive)
  (if (cluck--draw-source-p)
      (cluck-draw-repl)
    (cluck-repl)))

(defun cluck-switch-to-source ()
  "Return to the most recent Cluck source buffer."
  (interactive)
  (if (buffer-live-p cluck--last-source-buffer)
      (pop-to-buffer cluck--last-source-buffer)
    (message "No Cluck source buffer recorded.")))

(defun cluck--trim-output (text)
  "Collapse and trim TEXT for inline overlays."
  (let ((collapsed (replace-regexp-in-string "[ \t\n\r]+" " " text)))
    (replace-regexp-in-string "\\` \\| \\'" "" collapsed)))

(defun cluck--show-echo-output (output &optional fallback)
  "Show OUTPUT in the echo area, or FALLBACK when OUTPUT is empty."
  (let ((text (cluck--trim-output output)))
    (message "%s" (if (or (string= text "") (string= text "loaded"))
                      (or fallback "")
                    text))
    text))

(defun cluck--load-file-command (path)
  "Return a Cluck expression that loads PATH and prints any error."
  (format "(handle-exceptions exn (list 'error exn) (begin (load-file %S) 'loaded))"
          path))

(defun cluck--eval-string-sync (string &optional start timeout)
  "Evaluate STRING in the Cluck REPL and return the captured output."
  (let* ((buffer (cluck--ensure-repl-buffer start))
         (process (get-buffer-process buffer))
         (output-buffer (generate-new-buffer " *cluck-redirect*"))
         (result nil))
    (unwind-protect
        (progn
          (with-current-buffer buffer
            (comint-redirect-send-command-to-process string output-buffer process t t))
          (with-current-buffer buffer
            (let ((deadline (+ (float-time) (or timeout 10.0))))
              (while (and (not comint-redirect-completed)
                          (< (float-time) deadline))
                (accept-process-output process 0.1)))
            (unless comint-redirect-completed
              (error "Timed out waiting for Cluck evaluation")))
          (setq result
                (with-current-buffer output-buffer
                  (buffer-substring-no-properties (point-min) (point-max))))
          result)
      (when (buffer-live-p output-buffer)
        (kill-buffer output-buffer)))
    result))

(defun cluck--send-string (string &optional start timeout)
  "Send STRING to the Cluck REPL and return its output."
  (setq cluck--last-source-buffer (current-buffer))
  (cluck--eval-string-sync string start timeout))

(defun cluck--show-inline-result (end result)
  "Show RESULT inline after END."
  (let ((text (cluck--trim-output result)))
    (unless (string= text "")
      (dolist (ov (overlays-at end))
        (when (overlay-get ov 'cluck-result-overlay)
          (delete-overlay ov)))
      (let* ((start (if (> end (point-min)) (1- end) end))
             (finish (if (> end (point-min)) end (min (point-max) (1+ end))))
             (ov (make-overlay start finish)))
        (overlay-put ov 'cluck-result-overlay t)
        (overlay-put ov 'priority 1000)
        (overlay-put ov 'evaporate t)
        (overlay-put ov 'after-string
                     (propertize (concat " " cluck-inline-result-prefix text)
                                 'face 'shadow))))))

(defun cluck--symbol-at-point ()
  "Return the symbol at point as text."
  (or (thing-at-point 'symbol t)
      (error "No symbol at point")))

(defun cluck--show-doc-output (output)
  "Display OUTPUT in the Cluck doc buffer."
  (let ((buffer (get-buffer-create cluck-doc-buffer-name)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert output)
        (goto-char (point-min))
        (special-mode)))
    (display-buffer buffer)))

(defun cluck-send-region (start end)
  "Send the region between START and END to the Cluck REPL."
  (interactive "r")
  (cluck--show-echo-output
   (cluck--send-string (buffer-substring-no-properties start end))
   "Cluck region evaluated"))

(defun cluck-send-last-sexp ()
  "Send the sexp immediately before point to the Cluck REPL."
  (interactive)
  (let ((end (point)))
    (save-excursion
      (backward-sexp)
      (cluck--show-inline-result
       end
       (cluck--send-string (buffer-substring-no-properties (point) end))))))

(defun cluck-send-defun ()
  "Send the current top-level form to the Cluck REPL."
  (interactive)
  (save-excursion
    (beginning-of-defun)
    (let ((start (point)))
      (end-of-defun)
      (cluck--show-inline-result
       (point)
       (cluck--send-string (buffer-substring-no-properties start (point)))))))

(defun cluck-send-buffer ()
  "Send the whole buffer to the Cluck REPL."
  (interactive)
  (cluck--show-echo-output
   (cluck--send-string (buffer-substring-no-properties (point-min) (point-max)))
   "Cluck buffer evaluated"))

(defun cluck-load-file ()
  "Load the current file in the Cluck REPL."
  (interactive)
  (unless buffer-file-name
    (error "Current buffer is not visiting a file"))
  (cluck--show-echo-output
   (cluck--send-string (format "(load-file %S)" (expand-file-name buffer-file-name)))
   (format "Loaded %s" (file-name-nondirectory buffer-file-name))))

(defun cluck-describe-symbol ()
  "Show documentation for the symbol at point."
  (interactive)
  (cluck--show-doc-output
   (cluck--send-string (format "(doc %s)" (cluck--symbol-at-point)))))

(defun cluck--definition-name (symbol)
  "Return the unqualified definition name for SYMBOL."
  (let* ((text (if (symbolp symbol) (symbol-name symbol) symbol))
         (parts (split-string text "/")))
    (car (last parts))))

(defun cluck--definition-patterns (name)
  "Return regexps that may match a definition for NAME."
  (let ((q (regexp-quote name)))
    (list
     (format "^[[:space:]]*(defn[[:space:]]+%s\\_>" q)
     (format "^[[:space:]]*(def[[:space:]]+%s\\_>" q)
     (format "^[[:space:]]*(define-syntax[[:space:]]+%s\\_>" q)
     (format "^[[:space:]]*(define[[:space:]]+(%s\\_>" q)
     (format "^[[:space:]]*(define[[:space:]]+%s\\_>" q))))

(defun cluck--project-source-file-p (file)
  "Return non-nil when FILE should be searched for Cluck definitions."
  (not (or (string-match-p "/\\.worktrees/" file)
           (string-match-p "/build/" file)
           (string-match-p "/\\.git/" file))))

(defun cluck--jump-to-match (file line)
  "Jump to FILE at LINE and push the marker stack."
  (xref-push-marker-stack)
  (find-file file)
  (goto-char (point-min))
  (forward-line (1- line))
  (recenter))

(defun cluck--current-buffer-definition-location (name)
  "Return (FILE . LINE) for NAME in the current buffer, if present."
  (when buffer-file-name
    (save-excursion
      (goto-char (point-min))
      (catch 'found
        (dolist (pattern (cluck--definition-patterns name))
          (goto-char (point-min))
          (when (re-search-forward pattern nil t)
            (throw 'found (cons buffer-file-name
                                (line-number-at-pos (match-beginning 0))))))
        nil))))

(defun cluck--project-definition-location (name)
  "Return (FILE . LINE) for NAME found under the Cluck project root."
  (let* ((root (cluck--project-root))
         (patterns (cluck--definition-patterns name))
         (files (directory-files-recursively
                 root
                 "\\.\\(clk\\|clj\\|clj\\.scm\\|scm\\)\\'")))
    (catch 'found
      (dolist (file files)
        (when (cluck--project-source-file-p file)
          (dolist (pattern patterns)
            (with-temp-buffer
              (insert-file-contents file)
              (goto-char (point-min))
              (when (re-search-forward pattern nil t)
                (throw 'found
                       (cons file
                             (line-number-at-pos (match-beginning 0)))))))))
      nil)))

(defun cluck-jump-to-definition ()
  "Jump to the definition of the symbol at point."
  (interactive)
  (let* ((symbol (cluck--symbol-at-point))
         (name (cluck--definition-name symbol))
         (location (or (cluck--current-buffer-definition-location name)
                       (cluck--project-definition-location name))))
    (unless location
      (error "No definition found for %s" name))
    (cluck--jump-to-match (car location) (cdr location))))

(defconst cluck--completion-symbol-chars
  "A-Za-z0-9_?!*+<>=./-"
  "Characters treated as part of Cluck completion symbols.")

(defun cluck--buffer-require-alias-target (alias)
  "Return the namespace symbol imported as ALIAS in the current buffer."
  (save-excursion
    (goto-char (point-min))
    (let ((pattern (format "\\[\\s-*\\([[:alnum:]._-]+\\)\\(?:\\s-\\|\n\\)+:as\\(?:\\s-\\|\n\\)+%s\\_>"
                           (regexp-quote alias))))
      (catch 'found
        (while (re-search-forward pattern nil t)
          (throw 'found (intern (match-string-no-properties 1))))
        nil))))

(defun cluck--namespace-source-file (ns)
  "Return a readable source file for namespace NS, if one can be found."
  (let* ((root (file-name-as-directory (cluck--project-root)))
         (direct (expand-file-name
                  (concat (replace-regexp-in-string "\\." "/" (symbol-name ns))
                          ".clk")
                  root)))
    (cond
      ((file-readable-p direct) direct)
      (t
       (let ((pattern (format "^(ns\\s-+%s\\_>" (regexp-quote (symbol-name ns))))
             (files (directory-files-recursively root "\\.clk\\'")))
         (catch 'found
           (dolist (file files)
             (when (cluck--project-source-file-p file)
               (with-temp-buffer
                 (insert-file-contents file nil 0 2048)
                 (goto-char (point-min))
                 (when (re-search-forward pattern nil t)
                   (throw 'found file)))))
           nil))))))

(defun cluck--source-public-symbols (file)
  "Return public symbol names declared in FILE."
  (let ((patterns
         '("^[[:space:]]*(defn[[:space:]]+\\([[:alnum:]_?!*+<>=-]+\\)\\_>"
           "^[[:space:]]*(def[[:space:]]+\\([[:alnum:]_?!*+<>=-]+\\)\\_>"
           "^[[:space:]]*(define-syntax[[:space:]]+\\([[:alnum:]_?!*+<>=-]+\\)\\_>"
           "^[[:space:]]*(define[[:space:]]+(\\([[:alnum:]_?!*+<>=-]+\\)\\_>"
           "^[[:space:]]*(define[[:space:]]+\\([[:alnum:]_?!*+<>=-]+\\)\\_>"))
        (names '()))
    (with-temp-buffer
      (insert-file-contents file)
      (dolist (pattern patterns)
        (goto-char (point-min))
        (while (re-search-forward pattern nil t)
          (let ((name (match-string-no-properties 1)))
            (unless (string-prefix-p "cluck-" name)
              (push name names))))))
    (delete-dups (nreverse names))))

(defvar-local cluck--completion-loaded-ns-form nil)

(defun cluck--buffer-ns-form-text ()
  "Return the leading ns form text in the current buffer, or nil."
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward "^[[:space:]]*(ns\\_>" nil t)
      (goto-char (match-beginning 0))
      (let ((beg (point)))
        (condition-case nil
            (progn
              (forward-sexp 1)
              (buffer-substring-no-properties beg (point)))
          (error nil))))))

(defun cluck--repl-module-export-symbols (module prefix)
  "Return exported symbol names for MODULE, prefixed with PREFIX/."
  (let ((output (string-trim
                 (cluck--send-string
                  (format "(begin (import apropos-api %s) (apropos-information-list '%s))"
                          module module)))))
    (condition-case nil
        (let* ((parsed (car (read-from-string output)))
               (needle (concat prefix "/"))
               (names (mapcar (lambda (entry)
                                (let ((binding (and (consp entry) (car entry))))
                                  (when (and (consp binding) (symbolp (cdr binding)))
                                    (concat prefix "/" (symbol-name (cdr binding))))))
                              (if (listp parsed) parsed '()))))
          (cl-remove-if-not (lambda (name) (string-prefix-p needle name)) names))
      (error nil))))

(defun cluck--repl-namespace-public-symbols (module prefix)
  "Return public symbol names for Cluck namespace MODULE, prefixed with PREFIX/."
  (let ((output (string-trim
                 (cluck--send-string
                  (format "(keys (ns-publics '%s))" module)))))
    (condition-case nil
        (let* ((parsed (car (read-from-string output)))
               (needle (concat prefix "/"))
               (names (mapcar (lambda (sym)
                                (when (symbolp sym)
                                  (concat prefix "/" (symbol-name sym))))
                              (if (listp parsed) parsed '()))))
          (cl-remove-if-not (lambda (name) (string-prefix-p needle name)) names))
      (error nil))))

(defun cluck--completion-candidates-for-prefix (prefix)
  "Return completion candidates for PREFIX before the slash."
  (let* ((target (or (cluck--buffer-require-alias-target prefix)
                     (when (string-match-p "\\." prefix)
                       (intern prefix))))
         (file (and target (cluck--namespace-source-file target))))
    (cond
      (file
       (let ((source-symbols (cluck--source-public-symbols file)))
         (if source-symbols
             (mapcar (lambda (name) (concat prefix "/" name))
                     source-symbols)
           (if (string-match-p "\\." prefix)
               (cluck--repl-namespace-public-symbols target prefix)
             nil))))
      (target
       (if (string-match-p "\\." prefix)
           (cluck--repl-namespace-public-symbols target prefix)
         (cluck--repl-module-export-symbols target prefix)))
      (t nil))))

(defun cluck-completion-at-point ()
  "Complete namespace-qualified Cluck symbols like `str/trim`."
  (unless (or (nth 3 (syntax-ppss))
              (nth 4 (syntax-ppss)))
    (let* ((end (point))
           (beg (progn
                   (skip-chars-backward cluck--completion-symbol-chars)
                   (point)))
           (token (buffer-substring-no-properties beg end))
           (slash (string-match "/" token)))
      (when slash
        (let* ((prefix (substring token 0 slash))
               (candidates (cluck--completion-candidates-for-prefix prefix)))
          (when candidates
            (list beg end candidates)))))))

(defun cluck-complete ()
  "Complete namespace-qualified Cluck symbols on demand."
  (interactive)
  (let ((capf (cluck-completion-at-point)))
    (if capf
        (completion-in-region (nth 0 capf) (nth 1 capf) (nth 2 capf))
      (call-interactively #'indent-for-tab-command))))

(defun cluck--disable-auto-completion ()
  "Disable automatic completion in Cluck buffers."
  (setq-local completion-at-point-functions nil)
  (setq-local company-backends nil)
  (setq-local company-idle-delay nil)
  (when (fboundp 'company-mode)
    (company-mode -1)))

(with-eval-after-load 'setup-cluck-mode
  (add-hook 'cluck-mode-hook #'cluck--enable-inline-result-clearing)
  (add-hook 'cluck-mode-hook #'cluck--disable-auto-completion)
  (define-key cluck-mode-map (kbd "C-c C-z") #'cluck-switch-to-repl)
  (define-key cluck-mode-map (kbd "C-c C-e") #'cluck-send-last-sexp)
  (define-key cluck-mode-map (kbd "C-c C-c") #'cluck-send-defun)
  (define-key cluck-mode-map (kbd "C-c C-r") #'cluck-send-region)
  (define-key cluck-mode-map (kbd "C-c C-b") #'cluck-send-buffer)
  (define-key cluck-mode-map (kbd "C-c C-k") #'cluck-send-buffer)
  (define-key cluck-mode-map (kbd "C-c C-l") #'cluck-load-file)
  (define-key cluck-mode-map (kbd "C-c C-s") #'cluck-send-last-sexp)
  (define-key cluck-mode-map (kbd "C-c C-d") #'cluck-describe-symbol)
  (define-key cluck-mode-map (kbd "M-.") #'cluck-jump-to-definition)
  (define-key cluck-mode-map (kbd "M-,") #'xref-pop-marker-stack)
  (define-key cluck-mode-map (kbd "TAB") #'cluck-complete)
  (define-key cluck-mode-map (kbd "<tab>") #'cluck-complete)
  (define-key cluck-mode-map (kbd "C-x C-e") #'cluck-send-last-sexp)
  (define-key cluck-mode-map (kbd "C-M-x") #'cluck-send-defun))

(define-key cluck-repl-mode-map (kbd "C-c C-z") #'cluck-switch-to-source)

(provide 'setup-cluck-repl)

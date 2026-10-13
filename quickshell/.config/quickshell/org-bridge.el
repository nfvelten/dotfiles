;;; org-bridge.el --- Yerba Org integration -*- lexical-binding: t; -*-
(require 'org)
(require 'json)

(defun yerba-org-file (file)
  (let ((root (file-name-as-directory (file-truename org-directory)))
        (path (file-truename file)))
    (unless (and (file-in-directory-p path root) (string-suffix-p ".org" path))
      (error "Arquivo fora do vault Org"))
    path))

(defun yerba-org-focus ()
  (let ((frame (or (seq-find (lambda (f) (display-graphic-p f)) (frame-list))
                   (error "Open a graphical Emacs frame to continue"))))
    (select-frame-set-input-focus frame)))

(defun yerba-org-open (file line)
  (find-file (yerba-org-file file))
  (widen)
  (goto-char (point-min))
  (forward-line (max 0 (1- line)))
  (org-fold-show-context 'link-search)
  (recenter)
  t)

(defun yerba-elfeed-open-url (url)
  "Open an RSS entry in Elfeed in the same Emacs scratchpad frame as Org notes."
  (require 'elfeed)
  (require 'elfeed-search)
  (elfeed)
  (elfeed-db-ensure)
  (let ((entry (seq-find (lambda (candidate)
                           (equal (elfeed-entry-link candidate) url))
                         (hash-table-values elfeed-db-entries))))
    (if entry
        (elfeed-show-entry entry)
      (progn
        ;; The local DB can be empty after a fresh setup or a long pause.
        ;; Update only when the requested entry is missing; otherwise the
        ;; asynchronous refresh would replace the entry view with the search.
        (when (fboundp 'elfeed-update)
          (elfeed-update))
        (message "Atualizando feeds para encontrar: %s" url))))
  t)

(defun yerba-org-today ()
  (unless (fboundp 'nf/daily-note) (error "Function nf/daily-note unavailable"))
  (nf/daily-note)
  t)

(defun yerba-org-capture (text)
  "Capture a checkbox using the daily template and the live Emacs buffer."
  (unless (fboundp 'nf/daily-note) (error "Function nf/daily-note unavailable"))
  (setq text (string-trim text))
  (when (or (string-empty-p text) (string-match-p "[\n\r]" text))
    (error "Write the task on a single line"))
  (save-window-excursion
    (save-excursion
      (nf/daily-note)
      (yerba-org-file buffer-file-name)
      ;; Never persist unrelated unsaved edits as a side effect of capture.
      (when (and (file-exists-p buffer-file-name) (buffer-modified-p))
        (error "Save the daily note in Emacs before capturing"))
      (when (and (file-exists-p buffer-file-name) (not (verify-visited-file-modtime (current-buffer))))
        (error "Note changed on disk; revert the buffer in Emacs"))
      (save-restriction
        (widen)
        (goto-char (point-min))
        (if (re-search-forward "^\\*+ Tasks: #personal[ \t]*$" nil t)
            (org-end-of-subtree t t)
          (goto-char (point-max))
          (insert "\n*** Tasks: #personal\n"))
        (unless (bolp) (insert "\n"))
        (insert "- [ ] " text "\n")
        (save-buffer))
      buffer-file-name)))

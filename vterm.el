;;; vterm.el --- This package implements a terminal via libvterm

;;; Commentary:
;;
;; This Emacs module implements a bridge to libvterm to display a terminal in a
;; Emacs buffer.

;;; Code:

(require 'vterm-module)
(require 'subr-x)
(require 'cl-lib)

(defvar vterm-term nil
  "Pointer to struct Term.")
(make-variable-buffer-local 'vterm-term)

(defvar vterm-buffers nil
  "List of active vterm-buffers.")

(defvar vterm-keymap-exceptions '("C-x" "C-u" "C-g" "C-h" "M-x" "M-o")
  "Exceptions for vterm-keymap.

If you use a keybinding with a prefix-key that prefix-key cannot
be send to the terminal.")

(define-derived-mode vterm-mode fundamental-mode "VTerm"
  "Mayor mode for vterm buffer."
  (buffer-disable-undo)
  (setq vterm-term (vterm-new (window-body-height) (window-body-width))
        buffer-read-only t)
  (setq-local scroll-conservatively 101)
  (setq-local scroll-margin 0)
  (add-hook 'kill-buffer-hook #'vterm-kill-buffer-hook t t)
  (add-hook 'window-size-change-functions #'vterm-window-size-change t t))

;; Keybindings
(define-key vterm-mode-map [t] #'vterm-self-insert)
(define-key vterm-mode-map [mouse-1] nil)
(define-key vterm-mode-map [mouse-2] nil)
(define-key vterm-mode-map [mouse-3] nil)
(define-key vterm-mode-map [mouse-4] #'ignore)
(define-key vterm-mode-map [mouse-5] #'ignore)
(dolist (prefix '("M-" "C-"))
  (dolist (char (cl-loop for char from ?a to ?z
                         collect char))
    (let ((key (concat prefix (char-to-string char))))
      (unless (cl-member key vterm-keymap-exceptions)
        (define-key vterm-mode-map (kbd key) #'vterm-self-insert)))))
(dolist (exception vterm-keymap-exceptions)
  (define-key vterm-mode-map (kbd exception) nil))

(defun vterm-self-insert ()
  "Sends invoking key to libvterm."
  (interactive)
  (let* ((modifiers (event-modifiers last-input-event))
         (shift (memq 'shift modifiers))
         (meta (memq 'meta modifiers))
         (ctrl (memq 'control modifiers))
         (window (posn-window (event-end last-input-event))))
    (when-let ((key (key-description (vector (event-basic-type last-input-event))))
               (inhibit-redisplay t)
               (inhibit-read-only t))
      (when (equal modifiers '(shift))
        (setq key (upcase key)))
      (with-selected-window window
        (vterm-update vterm-term key shift meta ctrl)))))

(defun vterm-create ()
  "Create a new vterm."
  (interactive)
  (let ((buffer (generate-new-buffer "vterm")))
    (add-to-list 'vterm-buffers buffer)
    (pop-to-buffer buffer)
    (vterm-mode)))

(defun vterm-event ()
  "Update the vterm BUFFER."
  (interactive)
  (let ((inhibit-redisplay t)
        (inhibit-read-only t))
    (mapc (lambda (buffer)
            (with-current-buffer buffer
              (unless (vterm-update vterm-term)
                (kill-buffer-and-window))))
          vterm-buffers)))

(define-key special-event-map [sigusr1] #'vterm-event)

(defun vterm-kill-buffer-hook ()
  "Kill the corresponding process of vterm."
  (when (eq major-mode 'vterm-mode)
    (setq vterm-buffers (remove (current-buffer) vterm-buffers))
    (vterm-kill vterm-term)))

(defun vterm-window-size-change (frame)
  "Notify the vterm over size-change in FRAME."
  (dolist (window (window-list frame 1))
    (let ((buffer (window-buffer window)))
      (with-current-buffer buffer
        (when (eq major-mode 'vterm-mode)
          (vterm-set-size vterm-term (window-body-height) (window-body-width)))))))

(provide 'vterm)
;;; vterm.el ends here

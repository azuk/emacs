;;; add-log.el --- change log maintenance commands for Emacs

;; Maintainer: FSF

;; Copyright (C) 1985, 86, 87, 88, 89, 90, 91, 1992
;;	Free Software Foundation, Inc.

;; This file is part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

;;; Code:

;;;###autoload
(defvar change-log-default-name nil
  "*Name of a change log file for \\[add-change-log-entry].")

(defun change-log-name ()
  (or change-log-default-name
      (if (eq system-type 'vax-vms) "$CHANGE_LOG$.TXT" "ChangeLog")))

(defun prompt-for-change-log-name ()
  "Prompt for a change log name."
  (let ((default (change-log-name)))
    (expand-file-name
     (read-file-name (format "Log file (default %s): " default)
		     nil default))))

;;;###autoload
(defun add-change-log-entry (&optional whoami file-name other-window)
  "Find change log file and add an entry for today.
Optional arg (interactive prefix) non-nil means prompt for user name and site.
Second arg is file name of change log.  If nil, uses `change-log-default-name'.
Third arg OTHER-WINDOW non-nil means visit in other window."
  (interactive (list current-prefix-arg
		     (prompt-for-change-log-name)))
  (let* ((full-name (if whoami
			(read-input "Full name: " (user-full-name))
		      (user-full-name)))
	 ;; Note that some sites have room and phone number fields in
	 ;; full name which look silly when inserted.  Rather than do
	 ;; anything about that here, let user give prefix argument so that
	 ;; s/he can edit the full name field in prompter if s/he wants.
	 (login-name (if whoami
			 (read-input "Login name: " (user-login-name))
		       (user-login-name)))
	 (site-name (if whoami
			(read-input "Site name: " (system-name))
		      (system-name)))
	 (defun (add-log-current-defun))
	 entry entry-position empty-entry)
    (or file-name
	(setq file-name (or change-log-default-name
			    default-directory)))
    (setq file-name (if (file-directory-p file-name)
			(expand-file-name (change-log-name) file-name)
		      (expand-file-name file-name)))
    (set (make-local-variable 'change-log-default-name) file-name)
    (if buffer-file-name
	(setq entry (if (string-match
			 (concat "^" (regexp-quote (file-name-directory
						    file-name)))
			 buffer-file-name)
			(substring buffer-file-name (match-end 0))
		      (file-name-nondirectory buffer-file-name))))
    ;; Never want to add a change log entry for the ChangeLog buffer itself.
    (if (equal file-name entry)
	(setq entry nil
	      defun nil))
    (if (and other-window (not (equal file-name buffer-file-name)))
	(find-file-other-window file-name)
      (find-file file-name))
    (undo-boundary)
    (goto-char (point-min))
    (if (not (and (looking-at (substring (current-time-string) 0 10))
		  (looking-at (concat ".* " full-name "  (" login-name "@"))))
	(progn (insert (current-time-string)
		       "  " full-name
		       "  (" login-name
		       "@" site-name ")\n\n")))
    (goto-char (point-min))
    (setq empty-entry
	  (and (search-forward "\n\t* \n" nil t)
	       (1- (point))))
    (if (and entry
	     (not empty-entry))
	;; Look for today's entry for the same file.
	;; If there is an empty entry (just a `*'), take the hint and
	;; use it.  This is so that C-x a from the ChangeLog buffer
	;; itself can be used to force the next entry to be added at
	;; the beginning, even if there are today's entries for the
	;; same file (but perhaps different revisions).
	(let ((entry-boundary (save-excursion
				(and (re-search-forward "\n[A-Z]" nil t)
				     (point)))))
	  (setq entry-position (save-excursion
				 (and (re-search-forward
				       (concat
					(regexp-quote (concat "* " entry))
					;; don't accept `foo.bar' when
					;; looking for `foo':
					"[ \n\t,:]")
				       entry-boundary
				       t)
				      (1- (match-end 0)))))))
    (cond (entry-position
	   ;; Move to the existing entry for the same file.
	   (goto-char entry-position)
	   (re-search-forward "^\\s *$")
	   (open-line 1)
	   (indent-relative-maybe))
	  (empty-entry
	   ;; Put this file name into the existing empty entry.
	   (goto-char empty-entry)
	   (if entry
	       (insert entry)))
	  (t
	   ;; Make a new entry.
	   (forward-line 1)
	   (while (looking-at "\\sW")
	     (forward-line 1))
	   (delete-region (point)
			  (progn
			    (skip-chars-backward "\n")
			    (point)))
	   (open-line 3)
	   (forward-line 2)
	   (indent-to left-margin)
	   (insert "* " (or entry ""))))
    ;; Point is at the entry for this file,
    ;; either at the end of the line or at the first blank line.
    (if defun
	(progn
	  ;; Make it easy to get rid of the function name.
	  (undo-boundary)
	  (insert (if (save-excursion
			(beginning-of-line 1)
			(looking-at "\\s *$")) 
		      ""
		    " ")
		  "(" defun "): "))
      (if (not (save-excursion
		 (beginning-of-line 1)
		 (looking-at "\\s *\\(\\*\\s *\\)?$")))
	  (insert ":")))))

;;;###autoload
(define-key ctl-x-4-map "a" 'add-change-log-entry-other-window)

;;;###autoload
(defun add-change-log-entry-other-window (&optional whoami file-name)
  "Find change log file in other window and add an entry for today.
First arg (interactive prefix) non-nil means prompt for user name and site.
Second arg is file name of change log.
Interactively, with a prefix argument, the file name is prompted for."
  (interactive (if current-prefix-arg
		   (list current-prefix-arg
			 (prompt-for-change-log-name))))
  (add-change-log-entry whoami file-name t))

(defun change-log-mode ()
  "Major mode for editting change logs; like Indented Text Mode.
Prevents numeric backups and sets `left-margin' to 8 and `fill-column'
to 74.
New log entries are usually made with \\[add-change-log-entry]."
  (interactive)
  (kill-all-local-variables)
  (indented-text-mode)
  (setq major-mode 'change-log-mode)
  (setq mode-name "Change Log")
  (setq left-margin 8)
  (setq fill-column 74)
  ;; Let each entry behave as one paragraph:
  (set (make-local-variable 'paragraph-start) "^\\s *$\\|^^L")
  (set (make-local-variable 'paragraph-separate) "^\\s *$\\|^^L\\|^\\sw")
  ;; Let all entries for one day behave as one page.
  ;; Note that a page boundary is also a paragraph boundary.
  ;; Unfortunately the date line of a page actually belongs to
  ;; the next day, but I don't see how to avoid that since
  ;; page moving cmds go to the end of the match, and Emacs
  ;; regexps don't have a context feature.
  (set (make-local-variable 'page-delimiter) "^[A-Z][a-z][a-z] .*\n\\|^")
  (set (make-local-variable 'version-control) 'never)
  (set (make-local-variable 'adaptive-fill-regexp) "\\s *")
  (run-hooks 'change-log-mode-hook))

(defvar add-log-current-defun-header-regexp
  "^\\([A-Z][A-Z_ ]+\\|[a-z_---A-Z]+\\)[ \t]*[:=]"
  "*Heuristic regexp used by `add-log-current-defun' for unknown major modes.")

(defun add-log-current-defun ()
  "Return name of function definition point is in, or nil.

Understands Lisp, LaTeX (\"functions\" are chapters, sections, ...),
Texinfo (@node titles), and C.

Other modes are handled by a heuristic that looks in the 10K before
point for uppercase headings starting in the first column or
identifiers followed by `:' or `=', see variable
`add-log-current-defun-header-regexp'.

Has a preference of looking backwards."
  (save-excursion
    (cond ((memq major-mode '(emacs-lisp-mode lisp-mode))
	   (beginning-of-defun)
	   (forward-word 1)
	   (skip-chars-forward " ")
	   (buffer-substring (point)
			     (progn (forward-sexp 1) (point))))
	  ((eq major-mode 'c-mode)
	   ;; must be inside function body for this to work
	   (beginning-of-defun)
	   (forward-line -1)
	   (while (looking-at "[ \t\n]") ; skip typedefs of arglist
	     (forward-line -1))
	   (down-list 1)		; into arglist
	   (backward-up-list 1)
	   (skip-chars-backward " \t")
	   (buffer-substring (point)
			     (progn (backward-sexp 1)
				    (point))))
	  ((memq major-mode
		 '(TeX-mode plain-TeX-mode LaTeX-mode;; tex-mode.el
			    plain-tex-mode latex-mode;; cmutex.el
			    ))
	   (if (re-search-backward
		"\\\\\\(sub\\)*\\(section\\|paragraph\\|chapter\\)" nil t)
	       (progn
		 (goto-char (match-beginning 0))
		 (buffer-substring (1+ (point));; without initial backslash
				   (progn
				     (end-of-line)
				     (point))))))
	  ((eq major-mode 'texinfo-mode)
	   (if (re-search-backward "^@node[ \t]+\\([^,]+\\)," nil t)
	       (buffer-substring (match-beginning 1)
				 (match-end 1))))
	  (t
	   ;; If all else fails, try heuristics
	   (let (case-fold-search)
	     (if (re-search-backward add-log-current-defun-header-regexp
				     (- (point) 10000)
				     t)
		 (buffer-substring (match-beginning 1)
				   (match-end 1))))))))

;;; add-log.el ends here

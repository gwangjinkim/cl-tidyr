(in-package #:cl-tidyr)

;; Kept for pre-TR1 reshape callers; new verbs use typed C2 missingness.
(defun is-missing-p (val) (or (null val) (na-p val)))

(defun drop-na (data &rest cols)
  "R: tidyr::drop_na(). Keep complete rows in a shared tidyselect selection.
Omitted columns inspect all. Typed logical NIL is FALSE; list NIL is NULL.
Factor and temporal owners, including empty results, retain their prototypes."
  (when (%tr-grouped-p data)
    (return-from drop-na (%tr-regroup (apply #'drop-na (%tr-group-data data) cols) (%tr-group-keys data))))
  (let* ((names (%tr-selected-names data cols t))
         (columns (mapcar (lambda (name) (%tr-data-column data name)) names))
         (rows (loop for i below (cl-tibble:tbl-nrows data)
                     when (every (lambda (column) (not (%tr-missing (col-ref column i) column))) columns)
                       collect i)))
    (%tr-subset data (coerce rows 'vector))))

(defun %tr-replace-column (column replacement &optional rows)
  (let* ((replacement (%tr-replacement replacement column))
         (values (coerce (col->list column) 'vector)))
    (dotimes (i (length values))
      (when (and (or (null rows) (aref rows i)) (%tr-missing (aref values i) column))
        (setf (aref values i) replacement)))
    (%tr-restore values column)))
(defun replace-na (data replacements)
  "R: tidyr::replace_na(). Replace missing cells using lossless casts.
A tibble takes a flat property list or string-keyed alist of replacements;
a vector takes one scalar, and a list column takes a size-one list.
Atomic NIL is FALSE; only list NIL cells represent NULL."
  (cond
    ((%tr-grouped-p data)
     (%tr-regroup (replace-na (%tr-group-data data) replacements) (%tr-group-keys data)))
    ((typep data 'cl-tibble:tbl)
     (let ((pairs (%tr-pairs replacements)) (names (coerce (cl-tibble:tbl-names data) 'list)))
       (%tr-frame names
                  (mapcar (lambda (name)
                            (let ((column (%tr-data-column data name)) (pair (assoc name pairs :test #'equal)))
                              (if pair (%tr-replace-column column (cdr pair)) column))) names)
                  (cl-tibble:tbl-nrows data))))
    (t (let ((column (%tr-column data)))
         (let ((result (%tr-replace-column column replacements)))
           (if (listp data) (col->list result) result))))))

(defun %tr-fill-args (args)
  (let ((columns nil) (direction :down) (by nil) (by-p nil))
    (loop while args for item = (pop args)
          do (cond ((eq item :direction)
                    (unless args (%tr-error "Missing :direction value."))
                    (setf direction (%tr-mode (pop args))))
                   ((eq item :by)
                    (unless args (%tr-error "Missing :by value."))
                    (setf by (pop args) by-p t))
                   (t (push item columns))))
    (unless (member direction '(:down :up :downup :updown))
      (%tr-error "Direction must be down, up, downup or updown."))
    (values (nreverse columns) direction by by-p)))
(defun %tr-fill-pass (values indices column up)
  (let ((found nil) (previous nil))
    (dolist (i (if up (reverse indices) indices))
      (let ((value (aref values i)))
        (if (%tr-missing value column)
            (when found (setf (aref values i) previous))
            (setf found t previous value))))) values)
(defun .fill (data &rest args)
  "R: tidyr::fill(). Fill selected columns in four directions using C2 owners.
The empty selection leaves DATA unchanged. :BY is a temporary tidyselect
selection. Grouped data from a loaded cl-dplyr retains its grouping."
  (multiple-value-bind (selectors direction by by-p) (%tr-fill-args args)
    (let* ((grouped (%tr-grouped-p data))
           (base (if grouped (%tr-group-data data) data))
           (keys (if grouped (%tr-group-keys data)
                     (when by (%tr-selected-names base by))))
           (targets (%tr-selected-names base selectors))
           (names (coerce (cl-tibble:tbl-names base) 'list)))
      (when (and grouped by-p) (%tr-error "Cannot supply :by to grouped data."))
      (let* ((groups (if keys (mapcar #'cdr (%tr-groups base keys))
                         (list (loop for i below (cl-tibble:tbl-nrows base) collect i))))
             (result (%tr-frame names
                       (mapcar (lambda (name)
                                 (let ((column (%tr-data-column base name)))
                                   (if (member name targets :test #'equal)
                                       (let ((values (coerce (col->list column) 'vector)))
                                         (dolist (indices groups)
                                           (%tr-fill-pass values indices column (member direction '(:up :updown)))
                                           (when (member direction '(:downup :updown))
                                             (%tr-fill-pass values indices column (eq direction :downup))))
                                         (%tr-restore values column))
                                       column))) names)
                       (cl-tibble:tbl-nrows base))))
        (if grouped (%tr-regroup result keys) result)))))
(defun fill (data col &rest args)
  "R: tidyr::fill(). Fill COL using :direction and optional temporary :by groups.
COL can be a name, selector, or selector list. On ordinary sequences this
retains the original CL:FILL (sequence item &key start end) delegation."
  (if (or (typep data 'cl-tibble:tbl) (%tr-grouped-p data))
      (apply #'.fill data (list col) args)
      (apply #'cl:fill data col args)))
(defun fill-tibble (data col &key (direction :down) by)
  "R: tidyr::fill(). Compatibility entry point for one column selector."
  (.fill data col :direction direction :by by))

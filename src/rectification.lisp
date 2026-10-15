(in-package #:cl-tidyr)

(defun unique-values (vec)
  (col->list (%tr-unique-column (%tr-column vec) nil)))
(defun cartesian-product (lists)
  (if (null lists) (list nil)
      (loop for item in (car lists) nconc
            (loop for rest in (cartesian-product (cdr lists)) collect (cons item rest)))))
(defun %tr-unique-column (column full-levels)
  (let* ((prototype (vec-prototype column))
         (values (if (and full-levels (eq (col-type column) :factor))
                     (append (prototype-levels prototype)
                             (when (some #'na-p (col->list column)) (list *na*)))
                     (remove-duplicates (col->list column) :test #'%tr-cell-equal :from-end t))))
    (unless (eq (col-type column) :list)
      (setf values (stable-sort values (lambda (a b) (%tr-value< a b column)))))
    (%tr-restore values column nil)))
(defun %tr-grid-arguments (arguments allow-vary)
  (let ((pairs nil) (repair :check-unique) (vary :slowest))
    (loop while arguments
          for name = (pop arguments)
          do (unless arguments (%tr-error "Grid inputs must be name/value pairs."))
             (let ((value (pop arguments)))
               (cond ((eq name :name-repair) (setf repair value))
                     ((and allow-vary (eq name :vary)) (setf vary (%tr-mode value)))
                     (t (push (cons (%tr-name name) (%tr-argument-column value)) pairs)))))
    (unless (member vary '(:slowest :fastest)) (%tr-error ":vary must be slowest or fastest."))
    (values (nreverse pairs) repair vary)))
(defun %tr-grid (pairs repair vary)
  (let* ((sizes (mapcar (lambda (p) (col-length (cdr p))) pairs))
         (n (reduce #'* sizes :initial-value 1))
         (columns
           (loop for pair in pairs for index from 0
                 for stride = (reduce #'* (if (eq vary :fastest) (subseq sizes 0 index)
                                             (nthcdr (1+ index) sizes)) :initial-value 1)
                 collect (%tr-restore
                          (loop for row below n collect
                                (col-ref (cdr pair) (mod (floor row stride) (nth index sizes))))
                          (cdr pair) nil))))
    (%tr-frame (mapcar #'car pairs) columns n repair)))
(defun expand-grid (&rest arguments)
  "R: tidyr::expand_grid(). Cartesian product of flat name/value inputs.
The first input varies slowest; :vary :fastest reverses that convention.
:name-repair accepts tibble name repair. String keys disambiguate columns
named vary or name-repair. Zero-size inputs retain empty column prototypes."
  (multiple-value-bind (pairs repair vary) (%tr-grid-arguments arguments t)
    (%tr-grid pairs repair vary)))
(defun crossing (&rest arguments)
  "R: tidyr::crossing(). Sorted unique inputs followed by a Cartesian product.
Use flat name/value pairs and optional :name-repair. Factors include unused
levels and retain their level order; ordinary strings use pinned ICU 76.1 root collation."
  (multiple-value-bind (pairs repair ignored) (%tr-grid-arguments arguments nil)
    (declare (ignore ignored))
    (%tr-grid (mapcar (lambda (p) (cons (car p) (%tr-unique-column (cdr p) t))) pairs)
              repair :slowest)))
(defun nesting (&rest arguments)
  "R: tidyr::nesting(). Sorted unique observed rows from flat name/value inputs.
Size-one inputs recycle; other sizes must agree. Factor levels are retained
but unused levels do not create rows. :name-repair uses tibble strategies."
  (multiple-value-bind (pairs repair ignored) (%tr-grid-arguments arguments nil)
    (declare (ignore ignored))
    (let* ((sizes (mapcar (lambda (p) (col-length (cdr p))) pairs))
           (size (if sizes (or (find-if (lambda (n) (/= n 1)) sizes) 1) 1))
           (columns (mapcar (lambda (p)
                              (unless (or (= 1 (col-length (cdr p))) (= size (col-length (cdr p))))
                                (%tr-error "Nesting inputs must have common size."))
                              (recycle-to (cdr p) size)) pairs))
           (rows (remove-duplicates
                  (loop for i below size collect (mapcar (lambda (column) (col-ref column i)) columns))
                  :test #'%tr-row-equal :from-end t)))
      (setf rows (stable-sort rows (lambda (a b) (%tr-row< a b columns))))
      (%tr-frame (mapcar #'car pairs)
                 (loop for column in columns for index from 0
                       collect (%tr-restore (mapcar (lambda (row) (nth index row)) rows) column nil))
                 (length rows) repair))))

(defun %tr-expansion-arguments (data arguments complete-p)
  (let ((specs nil) (options nil))
    (loop while arguments for item = (pop arguments)
          do (cond ((and (consp item) (eq (car item) :options))
                    (unless (evenp (length (cdr item))) (%tr-error "Malformed :options control."))
                    (setf options (append (cdr item) options)))
                   ((and (member item (if complete-p '(:name-repair :fill :explicit) '(:name-repair)))
                         arguments
                         ;; A name that already denotes a column keeps its old meaning.
                         (not (find (%tr-name item) (cl-tibble:tbl-names data) :test #'equal)))
                    (setf options (append (list item (pop arguments)) options)))
                   (t (push item specs))))
    (loop for (key value) on options by #'cddr
          unless (member key (if complete-p '(:name-repair :fill :explicit) '(:name-repair)))
            do (%tr-error "Unknown expansion option ~S." key))
    (values (nreverse specs) options)))
(defun %tr-expansion-pair (data spec)
  (cond ((and (consp spec) (eq (car spec) :as) (= 3 (length spec)))
         (cons (%tr-name (second spec)) (%tr-argument-column (if (functionp (third spec)) (funcall (third spec) data) (third spec)))))
        ((and (consp spec) (= 2 (length spec)))
         (cons (%tr-name (first spec)) (%tr-argument-column (if (functionp (second spec)) (funcall (second spec) data) (second spec)))))
        ((or (stringp spec) (symbolp spec) (integerp spec))
         (let ((name (cl-tibble::resolve-col-name data spec))) (cons name (%tr-data-column data name))))
        (t (%tr-error "Invalid expansion specification: ~S." spec))))
(defun %tr-expansion-chunk (data spec)
  (cond ((typep spec 'cl-tibble:tbl) spec)
        ((and (consp spec) (eq (car spec) :nesting))
         (apply #'nesting (loop for item in (cdr spec)
                               for pair = (%tr-expansion-pair data item) append (list (car pair) (cdr pair)))))
        (t (let ((pair (%tr-expansion-pair data spec)))
             (%tr-frame (list (car pair)) (list (%tr-unique-column (cdr pair) t))
                        (col-length (%tr-unique-column (cdr pair) t)))))))
(defun %tr-expand-base (data specs repair)
  (unless specs (return-from %tr-expand-base (%tr-frame nil nil 1 repair)))
  (let* ((chunks (mapcar (lambda (spec) (%tr-expansion-chunk data spec)) specs))
         (sizes (mapcar #'cl-tibble:tbl-nrows chunks))
         (n (reduce #'* sizes :initial-value 1))
         (names nil) (columns nil))
    (loop for chunk in chunks for index from 0
          for stride = (reduce #'* (nthcdr (1+ index) sizes) :initial-value 1)
          do (loop for name across (cl-tibble:tbl-names chunk)
                   for column = (%tr-data-column chunk name)
                   do (push name names)
                      (push (%tr-restore
                             (loop for row below n collect (col-ref column (mod (floor row stride) (nth index sizes))))
                             column nil) columns)))
    (%tr-frame (nreverse names) (nreverse columns) n repair)))
(defun %tr-group-expand (data arguments complete-p)
  (let* ((base (%tr-group-data data)) (keys (%tr-group-keys data))
         (names (remove-if (lambda (name) (member name keys :test #'equal))
                           (coerce (cl-tibble:tbl-names base) 'list)))
         (groups (%tr-groups base keys))
         (frames
           (loop for (nil . indices) in groups collect
                 (let* ((subset (%tr-subset base (coerce indices 'vector) names))
                        (expanded (apply (if complete-p #'complete #'expand) subset arguments))
                        (n (cl-tibble:tbl-nrows expanded)))
                   (%tr-frame (append keys (coerce (cl-tibble:tbl-names expanded) 'list))
                              (append (mapcar (lambda (key) (col-subseq (%tr-data-column base key)
                                                                   (make-array n :initial-element (first indices)))) keys)
                                      (map 'list (lambda (name) (%tr-data-column expanded name)) (cl-tibble:tbl-names expanded)))
                              n)))))
    (let ((result
            (if frames (%tr-bind-frames frames nil)
                (let* ((subset (%tr-subset base #() names))
                       (expanded (apply (if complete-p #'complete #'expand) subset arguments)))
                  (%tr-frame
                   (append keys (coerce (cl-tibble:tbl-names expanded) 'list))
                   (append (mapcar (lambda (key) (col-subseq (%tr-data-column base key) #())) keys)
                           (map 'list (lambda (name) (col-subseq (%tr-data-column expanded name) #()))
                                (cl-tibble:tbl-names expanded)))
                   0)))))
      (%tr-regroup result keys))))
(defun expand (data &rest cols)
  "R: tidyr::expand(). Expand sorted unique columns, using all factor levels.
Existing name arguments remain valid. (:nesting :a :b) keeps observed pairs;
(:as name vector) supplies computed values. An already evaluated NESTING
tibble is also a chunk. Use (:options :name-repair strategy) for controls
when a column has the same name as an option. Grouping is retained."
  (when (%tr-grouped-p data) (return-from expand (%tr-group-expand data cols nil)))
  (multiple-value-bind (specs options) (%tr-expansion-arguments data cols nil)
    (%tr-expand-base data specs (getf options :name-repair :check-unique))))
(defun complete (data &rest cols)
  "R: tidyr::complete(). Complete combinations and retain original duplicate rows.
Expansion specs match EXPAND. :fill takes named replacements and :explicit
NIL limits replacement to newly created rows. Use (:options ...) controls
to disambiguate columns named fill/explicit/name-repair. Grouping is retained."
  (when (%tr-grouped-p data) (return-from complete (%tr-group-expand data cols t)))
  (multiple-value-bind (specs options) (%tr-expansion-arguments data cols t)
    (unless specs (return-from complete data))
    (let* ((expanded (%tr-expand-base data specs (getf options :name-repair :check-unique)))
           (keys (coerce (cl-tibble:tbl-names expanded) 'list))
           (old-names (coerce (cl-tibble:tbl-names data) 'list))
           (names (append keys (remove-if (lambda (name) (member name keys :test #'equal)) old-names)))
           (original-columns (mapcar (lambda (name) (when (member name old-names :test #'equal) (%tr-data-column data name))) names))
           (expanded-columns (mapcar (lambda (name) (when (member name keys :test #'equal) (%tr-data-column expanded name))) names))
           (prototypes (mapcar (lambda (a b) (if (and a b) (common-prototype a b) (vec-prototype (or a b)))) original-columns expanded-columns))
           (matched (make-array (cl-tibble:tbl-nrows data) :initial-element nil))
           (rows nil) (new nil))
      (dotimes (i (cl-tibble:tbl-nrows expanded))
        (let* ((key (mapcar (lambda (name) (col-ref (%tr-data-column expanded name) i)) keys))
               (matches (loop for j below (cl-tibble:tbl-nrows data)
                              when (%tr-row-equal key (mapcar (lambda (name)
                                                               (if (member name old-names :test #'equal)
                                                                   (col-ref (%tr-data-column data name) j) *na*)) keys))
                                collect j)))
          (dolist (j (or matches (list nil)))
            (when j (setf (aref matched j) t))
            (push (loop for name in names for a in original-columns for b in expanded-columns
                        collect (cond ((member name keys :test #'equal) (col-ref b i))
                                      (j (col-ref a j))
                                      (t (if (eq (col-type a) :list) nil *na*)))) rows)
            (push (null j) new))))
      (dotimes (j (length matched))
        (unless (aref matched j)
          (push (mapcar (lambda (column) (if column (col-ref column j) *na*)) original-columns) rows)
          (push nil new)))
      (setf rows (nreverse rows) new (coerce (nreverse new) 'vector))
      (let* ((columns (loop for prototype in prototypes for index from 0
                            collect (vec-cast (restore-column (coerce (mapcar (lambda (row) (nth index row)) rows) 'vector) prototype) prototype)))
             (fills (%tr-pairs (getf options :fill)))
             (explicit (getf options :explicit t)))
        (%tr-frame names
                   (loop for name in names for column in columns
                         for pair = (assoc name fills :test #'equal)
                         collect (if pair (%tr-replace-column column (cdr pair) (unless explicit new)) column))
                   (length rows) (getf options :name-repair :check-unique))))))

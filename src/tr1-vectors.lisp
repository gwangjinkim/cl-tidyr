(in-package #:cl-tidyr)

(defun %tr-sequence-time (seconds type)
  (let ((timestamp (local-time:unix-to-timestamp (floor seconds)
                    :nsec (round (* 1d9 (- seconds (floor seconds)))))))
    (if (eq type :date) (cast-value timestamp :datetime :date) timestamp)))

(defun full-seq (x period &key (tol 1d-6))
  "R: tidyr::full_seq(). Fill gaps in a periodic numeric or temporal column.
PERIOD and TOL are in days for :DATE and seconds for :DATETIME. Missing,
empty, nonperiodic or nonfinite inputs signal TIDYR-ERROR. Names are dropped."
  (let* ((column (%tr-column x)) (type (col-type column))
         (temporal (member type '(:date :datetime)))
         (values (mapcar (lambda (value)
                           (cond ((na-p value) (%tr-error "full-seq input cannot contain missing values."))
                                 (temporal (/ (+ (local-time:timestamp-to-unix value) (/ (local-time:nsec-of value) 1000000000d0))
                                              (if (eq type :date) 86400d0 1d0)))
                                 ((realp value) value)
                                 (t (%tr-error "full-seq requires numeric or date-time values.")))) (col->list column))))
    (unless (and (realp period) (plusp period) (realp tol) (not (minusp tol)))
      (%tr-error "Period must be positive and tolerance nonnegative."))
    (unless values (%tr-error "full-seq requires a finite input range."))
    (let* ((lo (reduce #'min values)) (hi (reduce #'max values))
           (remainder (mod (- hi lo) period))
           (adjusted-hi (if (<= (- period remainder) tol) (+ hi tol) hi))
           (size (1+ (floor (+ (/ (- adjusted-hi lo) period) 1d-10)))))
      (dolist (value values)
        (let ((remainder (mod (- value lo) period)))
          (unless (or (<= remainder tol) (<= (- period remainder) tol))
            (%tr-error "The sequence is not regular at period ~S." period))))
      (let ((result
              (if temporal
                  (restore-column
                   (coerce (loop for i below size
                                 for seconds = (* (+ lo (* i period)) (if (eq type :date) 86400d0 1d0))
                                 collect (%tr-sequence-time seconds type)) 'vector)
                   (vec-prototype column))
                  (make-typed-column (coerce (loop for i below size collect (+ lo (* i period))) 'vector)
                                     (if (and (every #'integerp values) (integerp period)) :int :double)))))
        result))))
(defun uncount (data weights &key (remove t) id)
  "R: tidyr::uncount(). Repeat rows by nonnegative whole weights.
WEIGHTS is a column name, scalar, vector or callback receiving the tibble.
:REMOVE drops the weights column only for a direct name. :ID adds counters
starting at one for each source row; these are values, not row positions."
  (when (%tr-grouped-p data)
    (let* ((base (%tr-group-data data)) (keys (%tr-group-keys data))
           (evaluated
             (if (functionp weights)
                 (let ((values (make-array (cl-tibble:tbl-nrows base))))
                   (dolist (group (funcall (%tr-dplyr-symbol "GROUP-GROUPS") data))
                     (let* ((indices (cdr group))
                            (column (%tr-argument-column (funcall weights (%tr-subset base (coerce indices 'vector)))))
                            (size (col-length column)))
                       (unless (or (= size 1) (= size (length indices)))
                         (%tr-error "Grouped weights must have size one or the group size."))
                       (loop for index in indices for i from 0
                             do (setf (aref values index) (col-ref column (if (= size 1) 0 i))))))
                   values)
                 weights)))
      (return-from uncount (%tr-regroup (uncount base evaluated :remove remove :id id) keys))))
  (let* ((named (or (keywordp weights) (stringp weights) (and weights (symbolp weights) (not (eq weights t)))))
         (column (if named (%tr-data-column data weights)
                     (%tr-argument-column (if (functionp weights) (funcall weights data) weights))))
         (n (cl-tibble:tbl-nrows data)) (size (col-length column))
         (indices nil) (ids nil))
    (unless (or (= size n) (= size 1)) (%tr-error "Weights must have size one or the row count."))
    (dotimes (i n)
      (let ((weight (col-ref column (if (= size 1) 0 i))))
        (when (member weight '(nil t)) (setf weight (if weight 1 0)))
        (unless (and (realp weight) (<= 0 weight 2147483647) (= weight (truncate weight)))
          (%tr-error "Weights must be finite nonnegative whole numbers."))
        (dotimes (j (truncate weight)) (push i indices) (push (1+ j) ids))))
    (let* ((names (remove-if (lambda (name) (and named remove (equal name (%tr-name weights))))
                             (coerce (cl-tibble:tbl-names data) 'list)))
           (indices (coerce (nreverse indices) 'vector))
           (columns (mapcar (lambda (name) (col-subseq (%tr-data-column data name) indices)) names)))
      (when id
        (let* ((name (%tr-name id)) (position (position name names :test #'equal))
               (values (make-typed-column (coerce (nreverse ids) 'vector) :int)))
          (if position (setf (nth position columns) values)
              (setf names (append names (list name)) columns (append columns (list values))))))
      (%tr-frame names columns (length indices)))))

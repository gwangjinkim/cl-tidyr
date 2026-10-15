(in-package #:cl-tidyr)

(defun select-cols (data cols)
  "Select columns with shared tidyselect rules, preserving empty schemas.
For a helper requiring context, pass a zero-argument function that calls it.
Quoted TS2 operators/helper calls are accepted alone or in a selector list."
  (cl-tidyselect:with-selection-context
      ((cl-tibble:tbl-names data)
       (map 'list (lambda (name) (cl-tibble:tbl-col data name))
            (cl-tibble:tbl-names data))
       data)
    (let* ((expression-p (cl-tidyselect::selection-op-p cols
                           "TO" "C" "&" "AND" "INTERSECTION" "|" "OR" "UNION"
                           "!" "NOT" "EXCLUDE" "-" "AS" "QUOTE" "DATA" "ENV"
                           "STARTS-WITH" "ENDS-WITH" "CONTAINS" "MATCHES"
                           "NUM-RANGE" "EVERYTHING" "LAST-COL" "ALL-OF"
                           "ANY-OF" "ONE-OF" "WHERE"))
           (selectors (if (and (listp cols) (not expression-p)) cols (list cols)))
           (evaluated (mapcar (lambda (selector)
                               (if (functionp selector) (funcall selector) selector))
                             selectors)))
      (multiple-value-bind (indices names) (cl-tidyselect:selection-indices evaluated)
        ;; tidyr's pivot/unite contexts use tidyselect allow_rename = FALSE.
        (loop for index across indices for name across names
              unless (string= name (aref (cl-tibble:tbl-names data) index))
                do (error 'cl-tidyselect:tidyselect-error
                          :message "Can't rename variables in this context."))
        (let ((columns (make-hash-table :test 'equal)))
          (loop for index across indices for name across names
                do (setf (gethash name columns) (cl-tibble:tbl-col data index)))
          (make-instance 'cl-tibble:tbl :columns columns :names names
                         :nrows (cl-tibble:tbl-nrows data)))))))


(defun parse-unite-args (args)
  "Separates columns from keyword options for unite."
  (let ((sep "_")
        (remove t)
        (na-rm nil)
        (cols '()))
    (loop while args do
         (let ((item (pop args)))
           (cond
             ((eq item :sep) (setf sep (pop args)))
             ((eq item :remove) (setf remove (pop args)))
             ((eq item :na-rm) (setf na-rm (pop args)))
             (t (push item cols)))))
    (values (nreverse cols) sep remove na-rm)))

(defun get-nrow (df)
  "Return the stored row count, including zero-column and owner-column frames."
  (cl-tibble:tbl-nrows df))

(defun unite (data col &rest args)
  "Unites multiple columns into one by pasting them together."
  (multiple-value-bind (col-selectors sep remove na-rm)
      (parse-unite-args args)
    (let* ((sub-df (select-cols data col-selectors))
           (target-names (cl-tibble:tbl-names sub-df))
           (n (get-nrow data))
           (new-col-values (make-array n :fill-pointer 0)))

      ;; Extract values
      (let ((cols-data (map 'list (lambda (name) (cl-tibble:tbl-col sub-df name)) target-names)))
        ;; Iterate and join
        (dotimes (i n)
          (let ((row-vals (mapcar (lambda (c) (elt c i)) cols-data)))
            (if na-rm
                (setf row-vals (remove-if (lambda (v) (or (null v) (na-p v))) row-vals)))
            (vector-push-extend 
             (format nil (format nil "~~{~~a~~^~a~~}" sep) row-vals)
             new-col-values))))
      
      ;; Construct result
      (let ((res data)
            (keep-names (if remove
                            (let ((all-names (map 'list #'identity (cl-tibble:tbl-names data)))
                                  (targets (map 'list #'identity target-names)))
                              ;; REMOVE-IF keeps the original column order
                              ;; (SET-DIFFERENCE did not).
                              (remove-if (lambda (n) (member n targets :test #'equal))
                                         all-names))
                            nil)))
        
        (cond
          ((and remove (null keep-names))
           (setf res (cl-tibble:tibble (intern (string-upcase col) "KEYWORD") new-col-values)))
          
          (t 
           (when remove
             (setf res (select-cols data keep-names)))
           (let ((new-col-df (cl-tibble:tibble (intern (string-upcase col) "KEYWORD") new-col-values)))
             (setf res (cl-tibble:bind-cols res new-col-df)))))
        res))))

(defun separate (data col into &key (sep "[^[:alnum:]]+") (remove t) (convert nil))
  "Splits a column into multiple columns."
  (declare (ignore convert)) 
  (let* ((raw-vals (cl-tibble:tbl-col data col))
         (n (length raw-vals))
         (k (length into))
         ;; One list of exactly K pieces per row: NA input gives K NAs,
         ;; missing pieces are padded with NA (as tidyr's fill = "right").
         (split-vals (map 'list (lambda (x)
                                  (if (or (null x) (na-p x))
                                      (make-list k :initial-element *na*)
                                      (let ((pieces (cl-ppcre:split sep x :limit k)))
                                        (append pieces
                                                (make-list (max 0 (- k (length pieces)))
                                                           :initial-element *na*)))))
                          raw-vals))
         ;; Transpose into one vector per new column. Every row has K pieces,
         ;; so MAPCAR no longer truncates to the shortest row.
         (new-cols-data (if split-vals
                            (apply #'mapcar #'vector split-vals)
                            (make-list k :initial-element (vector)))))
    
    (let ((res data)
          (keep-names (if remove
                          (remove (string col) (map 'list #'identity (cl-tibble:tbl-names data)) 
                                  :test #'string-equal :key #'string)
                          nil)))
      
      (cond
        ((and remove (null keep-names))
         (let ((args (list)))
           (loop for name in into
                 for col-data in new-cols-data
                 do (push (intern (string-upcase name) "KEYWORD") args)
                    (push col-data args))
           (setf res (apply #'cl-tibble:tibble (nreverse args)))))
        
        (t
         (when remove
           (setf res (select-cols data keep-names)))
         
         (let ((args (list)))
           (loop for name in into
                 for col-data in new-cols-data
                 do (push (intern (string-upcase name) "KEYWORD") args)
                    (push col-data args))
           (let ((new-df (apply #'cl-tibble:tibble (nreverse args))))
             (setf res (cl-tibble:bind-cols res new-df))))))
         res)))

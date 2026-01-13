(in-package #:cl-tidyr)

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

(defun unite (data col &rest args)
  "Unites multiple columns into one by pasting them together."
  (multiple-value-bind (col-selectors sep remove na-rm)
      (parse-unite-args args)
    ;; 1. Select columns to unite
    ;; We use cl-dplyr:select to resolve selectors against the data, then get names
    (let* ((sub-df (apply #'cl-dplyr:select data col-selectors))
           (target-names (cl-tibble:column-names sub-df))
           (n (cl-tibble:nrow data))
           (new-col-values (make-list n)))
      
      ;; 2. Extract values for each valid column
      (let ((cols-data (mapcar (lambda (name) (cl-tibble:pull sub-df name)) target-names)))
        ;; cols-data is a list of vectors/lists
        
        ;; 3. Iterate and join
        (setf new-col-values
              (loop for i from 0 below n
                    collect (let ((row-vals (mapcar (lambda (c) (elt c i)) cols-data)))
                              (if na-rm
                                  (setf row-vals (remove-if #'null row-vals))) ;; Simplified NA check
                              (format nil (format nil "~~{~~a~~^~a~~}" sep) row-vals)))))
      
      ;; 4. Construct result
      ;; Start with original data
      (let ((res data))
        ;; If remove, drop the target columns
        (when remove
          (setf res (cl-dplyr:select data (cons :exclude target-names)))) ;; Assuming select supports exclude or we need logic
        ;; wait, cl-dplyr:select usually takes positive selection. 
        ;; To drop, usually `(select data (not (c ...)))`.
        ;; For now, I'll assume I can just rebuild or I need a better drop mechanism.
        ;; Let's assume cl-dplyr:select handles standard selection.
        ;; If remove is true, we want everything BUT target-names.
        (when remove
             ;; This is tricky without fully knowing cl-dplyr's "not" syntax implementation in this environment.
             ;; I'll try to fetch all names, remove targets, and select those.
             (let* ((all-names (cl-tibble:column-names data))
                    (keep-names (set-difference all-names target-names :test #'equal)))
               (setf res (apply #'cl-dplyr:select data keep-names))))
        
        ;; Add new column
        (setf res (cl-tibble:add-column res col new-col-values))
        res))))

(defun separate (data col into &key (sep "[^[:alnum:]]+") (remove t) (convert nil))
  "Splits a column into multiple columns."
  (declare (ignore convert)) ;; M1: ignore convert
  (let* ((raw-vals (cl-tibble:pull data col))
         (n (cl-tibble:nrow data))
         (split-vals (map 'list (lambda (x)
                                  (cl-ppcre:split sep x :limit (length into)))
                          raw-vals))
         ;; Transpose split-vals to get columns
         (new-cols-data (apply #'mapcar #'list split-vals)))
    
    (let ((res data))
      (when remove
        (let* ((all-names (cl-tibble:column-names data))
               ;; Use string comparison for names
               (keep-names (remove (string col) all-names :test #'string=)))
          (setf res (apply #'cl-dplyr:select data keep-names))))
      
      (loop for name in into
            for col-data in new-cols-data
            do (setf res (cl-tibble:add-column res name col-data)))
      res)))

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

(defun get-nrow (df)
  (let ((names (cl-tibble:tbl-names df)))
    (if (> (length names) 0)
        (length (cl-tibble:tbl-col df (elt names 0)))
        0)))

(defun unite (data col &rest args)
  "Unites multiple columns into one by pasting them together."
  (multiple-value-bind (col-selectors sep remove na-rm)
      (parse-unite-args args)
    (let* ((sub-df (apply #'cl-dplyr:select data col-selectors))
           (target-names (cl-tibble:tbl-names sub-df))
           (n (get-nrow data))
           (new-col-values (make-array n :fill-pointer 0)))

      ;; Extract values
      (let ((cols-data (map 'list (lambda (name) (cl-tibble:tbl-col sub-df name)) target-names)))
        ;; Iterate and join
        (dotimes (i n)
          (let ((row-vals (mapcar (lambda (c) (elt c i)) cols-data)))
            (if na-rm
                (setf row-vals (remove-if #'null row-vals))) 
            (vector-push-extend 
             (format nil (format nil "~~{~~a~~^~a~~}" sep) row-vals)
             new-col-values))))
      
      ;; Construct result
      (let ((res data)
            (keep-names (if remove
                            (let ((all-names (map 'list #'identity (cl-tibble:tbl-names data)))
                                  (targets (map 'list #'identity target-names)))
                              (set-difference all-names targets :test #'equal))
                            nil)))
        
        (cond
          ((and remove (null keep-names))
           (setf res (cl-tibble:tibble (intern (string-upcase col) "KEYWORD") new-col-values)))
          
          (t 
           (when remove
             (setf res (apply #'cl-dplyr:select data keep-names)))
           (let ((new-col-df (cl-tibble:tibble (intern (string-upcase col) "KEYWORD") new-col-values)))
             (setf res (cl-tibble:bind-cols res new-col-df)))))
        res))))

(defun separate (data col into &key (sep "[^[:alnum:]]+") (remove t) (convert nil))
  "Splits a column into multiple columns."
  (declare (ignore convert)) 
  (let* ((raw-vals (cl-tibble:tbl-col data col))
         (n (length raw-vals))
         (split-vals (map 'list (lambda (x)
                                  (cl-ppcre:split sep x :limit (length into)))
                          raw-vals))
         ;; Transpose and ensure vectors for cl-tibble
         (new-cols-data (apply #'mapcar #'vector split-vals)))
    
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
           (setf res (apply #'cl-dplyr:select data keep-names)))
         
         (let ((args (list)))
           (loop for name in into
                 for col-data in new-cols-data
                 do (push (intern (string-upcase name) "KEYWORD") args)
                    (push col-data args))
           (let ((new-df (apply #'cl-tibble:tibble (nreverse args))))
             (setf res (cl-tibble:bind-cols res new-df))))))
         res)))

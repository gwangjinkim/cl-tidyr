(in-package #:cl-tidyr)

(defun unique-values (vec)
  (remove-duplicates (map 'list #'identity vec) :test #'equal))

(defun cartesian-product (lists)
  (if (null lists)
      (list nil)
      (let ((rest-prod (cartesian-product (cdr lists))))
        (loop for item in (car lists)
              nconc (loop for rest in rest-prod
                          collect (cons item rest))))))

(defun expand (data &rest cols)
  "Generates all combinations of the unique values in the specified columns."
  (let* ((col-keys (mapcar (lambda (c) (intern (string-upcase (string c)) "KEYWORD")) cols))
         (col-vectors (mapcar (lambda (c) (cl-tibble:tbl-col data c)) col-keys))
         (unique-vals-list (mapcar #'unique-values col-vectors))
         (product (cartesian-product unique-vals-list))
         (n (length product))
         (res-cols (mapcar (lambda (x) (make-array n)) cols)))
    
    ;; Fill result columns
    (loop for row in product
          for i from 0
          do (loop for val in row
                   for vec in res-cols
                   do (setf (aref vec i) val)))
    
    (let ((args (list)))
      (loop for name in cols
            for vec in res-cols
            do (push (intern (string-upcase (string name)) "KEYWORD") args)
               (push vec args))
      (apply #'cl-tibble:tibble (nreverse args)))))

(defun complete (data &rest cols)
  "Completes the data frame with missing combinations.
   Note: currently assumes 'cols' are the expansion columns. 
   Other columns will be filled with nil/NA for new rows."
  
  ;; 1. Expand the grouping columns
  (let* ((expanded (apply #'expand data cols))
         (n-expanded (get-nrow expanded))
         (expanded-keys (map 'list #'identity (cl-tibble:tbl-names expanded))) ;; Should match cols
         
         ;; Map original data for lookup
         ;; Key: list of values for expansion cols -> Row Index in Data
         (lookup (make-hash-table :test #'equal))
         (n-orig (get-nrow data))
         (col-keys (mapcar (lambda (c) (intern (string-upcase (string c)) "KEYWORD")) cols))
         (orig-key-vectors (mapcar (lambda (c) (cl-tibble:tbl-col data c)) col-keys)))
    
    (dotimes (i n-orig)
      (let ((key (mapcar (lambda (vec) (elt vec i)) orig-key-vectors)))
        (setf (gethash key lookup) i)))
    
    ;; 2. Rebuild result
    ;; For every row in expanded, look up in original.
    ;; If found, copy all columns.
    ;; If not found, copy expansion cols, set others to nil.
    
    (let* ((all-names (map 'list #'identity (cl-tibble:tbl-names data)))
           (other-names (set-difference all-names expanded-keys :test #'equal))
           (res-vectors (mapcar (lambda (x) (make-array n-expanded)) all-names))
           (expanded-vectors (mapcar (lambda (name) (cl-tibble:tbl-col expanded name)) expanded-keys)))
      
      (dotimes (i n-expanded)
        (let* ((key-vals (mapcar (lambda (vec) (elt vec i)) expanded-vectors))
               (orig-idx (gethash key-vals lookup)))
          
          ;; Fill expansion columns (always present)
          (loop for name in expanded-keys
                for val in key-vals
                do 
                ;; Find corresponding result vector
                (let ((pos (position name all-names :test #'equal)))
                  (setf (aref (elt res-vectors pos) i) val)))
          
          ;; Fill other columns
          (loop for name in other-names
                do
                (let ((pos (position name all-names :test #'equal)))
                  (if orig-idx
                      ;; Copy from original
                      (let ((orig-val (elt (cl-tibble:tbl-col data name) orig-idx)))
                        (setf (aref (elt res-vectors pos) i) orig-val))
                      ;; Else nil
                      (setf (aref (elt res-vectors pos) i) nil))))))
      
      ;; 3. Tibble
      (let ((args (list)))
        (loop for name in all-names
              for vec in res-vectors
              do (push (intern (string-upcase (string name)) "KEYWORD") args)
                 (push vec args))
        (apply #'cl-tibble:tibble (nreverse args))))))

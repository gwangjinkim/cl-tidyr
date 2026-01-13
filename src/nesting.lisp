(in-package #:cl-tidyr)

(defun nest (data new-col &rest data-cols)
  "Nests specified columns into a list-column of tibbles."
  (let* ((all-names (map 'list #'identity (cl-tibble:tbl-names data)))
         (nest-keys (mapcar (lambda (c) (intern (string-upcase (string c)) "KEYWORD")) data-cols))
         (group-keys (remove-if (lambda (n)
                                  (member (intern (string-upcase (string n)) "KEYWORD")
                                          nest-keys
                                          :test #'eq))
                                all-names))
         (n (get-nrow data)))
    
    ;; Group rows by grouping columns
    (let ((groups (make-hash-table :test #'equal))
          (groups-order (list)))
             
      (dotimes (i n)
        (let ((key (mapcar (lambda (k) (elt (cl-tibble:tbl-col data k) i)) group-keys)))
          (unless (gethash key groups)
            (push key groups-order))
          (push i (gethash key groups)))) ;; Push indices
      
      (setf groups-order (nreverse groups-order))
      
      ;; Build result
      (let* ((n-groups (length groups-order))
             (res-group-cols (mapcar (lambda (x) (make-array n-groups)) group-keys))
             (res-nest-col (make-array n-groups)))
        
        (loop for key in groups-order
              for i from 0
              do
              ;; Fill group columns
              (loop for val in key
                    for vec in res-group-cols
                    do (setf (aref vec i) val))
              
              ;; Fill nested column
              (let* ((indices (nreverse (gethash key groups))) ;; Indices of rows in this group
                     (n-nested (length indices))
                     (nested-args (list)))
                
                (loop for nest-k in nest-keys
                      do
                      (let ((nested-vec (make-array n-nested))
                            (orig-vec (cl-tibble:tbl-col data nest-k)))
                        (loop for idx in indices
                              for j from 0
                              do (setf (aref nested-vec j) (elt orig-vec idx)))
                        (push nest-k nested-args)
                        (push nested-vec nested-args)))
                
                (setf (aref res-nest-col i) 
                      (apply #'cl-tibble:tibble (nreverse nested-args)))))
        
        ;; Create Result Tibble
        (let ((args (list)))
          (loop for k in group-keys
                for vec in res-group-cols
                do (push k args)
                   (push vec args))
          (push (intern (string-upcase (string new-col)) "KEYWORD") args)
          (push res-nest-col args)
          (apply #'cl-tibble:tibble (nreverse args)))))))

(defun unnest (data col)
  "Unnests a list-column of tibbles."
  (let* ((nested-col (cl-tibble:tbl-col data col))
         (n-rows (get-nrow data))
         (all-names (map 'list #'identity (cl-tibble:tbl-names data)))
         (data-key (intern (string-upcase (string col)) "KEYWORD"))
         (other-keys (remove data-key all-names :test #'equal)))
    
    ;; First pass: calculate total size and structure
    (let ((total-rows 0)
          (nested-col-names nil))
      
      ;; Check first non-nil nested element to get names
      (dotimes (i n-rows)
        (let ((sub-df (elt nested-col i)))
          (when sub-df
            (incf total-rows (get-nrow sub-df))
            (unless nested-col-names
              (setf nested-col-names (map 'list #'identity (cl-tibble:tbl-names sub-df)))))))
      
      ;; Prepare Result Vectors
      (let ((res-other-cols (mapcar (lambda (x) (make-array total-rows)) other-keys))
            (res-nested-cols (mapcar (lambda (x) (make-array total-rows)) nested-col-names)))
        
        (let ((current-idx 0))
          (dotimes (i n-rows)
            (let ((sub-df (elt nested-col i)))
              (when sub-df
                (let ((n-sub (get-nrow sub-df)))
                  
                  ;; Copy repeated outer columns
                  (loop for k in other-keys
                        for vec in res-other-cols
                        do 
                        (let ((val (elt (cl-tibble:tbl-col data k) i)))
                           (dotimes (j n-sub)
                             (setf (aref vec (+ current-idx j)) val))))
                  
                  ;; Copy nested columns
                  (loop for k in nested-col-names
                        for vec in res-nested-cols
                        do
                        (let ((sub-vec (cl-tibble:tbl-col sub-df k)))
                          (dotimes (j n-sub)
                             (setf (aref vec (+ current-idx j)) (elt sub-vec j)))))
                  
                  (incf current-idx n-sub))))))
        
        ;; Construct Tibble
        (let ((args (list)))
          (loop for k in other-keys
                for vec in res-other-cols
                do (push k args)
                   (push vec args))
          (loop for k in nested-col-names
                for vec in res-nested-cols
                do (push k args)
                   (push vec args))
          (apply #'cl-tibble:tibble (nreverse args)))))))

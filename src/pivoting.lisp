(in-package #:cl-tidyr)

(defun pivot-longer (data cols &key (names-to "name") (values-to "value") (values-drop-na nil))
  "Pivots data from wide to long."
  (let* ((pivot-df (apply #'cl-dplyr:select data cols))
         (pivot-names (map 'list #'identity (cl-tibble:tbl-names pivot-df))) 
         (n-rows (get-nrow data)))
    
    (let* ((all-names (map 'list #'identity (cl-tibble:tbl-names data)))
           (id-names (set-difference all-names pivot-names :test #'equal)))
      
      (let ((new-id-cols (mapcar (lambda (x) (make-array 0 :fill-pointer 0 :adjustable t)) id-names))
            (new-key-col (make-array 0 :fill-pointer 0 :adjustable t))
            (new-val-col (make-array 0 :fill-pointer 0 :adjustable t)))
        
        (let ((id-data-cols (mapcar (lambda (name) (cl-tibble:tbl-col data name)) id-names))
              (pivot-data-cols (mapcar (lambda (name) (cl-tibble:tbl-col data name)) pivot-names)))
          
          (dotimes (i n-rows)
            (loop for p-name in pivot-names
                  for p-col in pivot-data-cols
                  do 
                  (let ((val (elt p-col i)))
                    (unless (and values-drop-na (is-missing-p val))
                      (vector-push-extend (string p-name) new-key-col)
                      (vector-push-extend val new-val-col)
                      (loop for id-col in id-data-cols
                            for target-vec in new-id-cols
                            do (vector-push-extend (elt id-col i) target-vec)))))))
        
        (let ((args (list)))
          (loop for name in id-names
                for vec in new-id-cols
                do (push (intern (string-upcase name) "KEYWORD") args)
                   (push vec args))
          (push (intern (string-upcase names-to) "KEYWORD") args)
          (push new-key-col args)
          (push (intern (string-upcase values-to) "KEYWORD") args)
          (push new-val-col args)
          (apply #'cl-tibble:tibble (nreverse args)))))))

(defun pivot-wider (data &key names-from values-from (values-fill *na*))
  "Pivots data from long to wide."
  ;; 1. Identify columns
  (let* ((all-names (map 'list #'identity (cl-tibble:tbl-names data)))
         (id-names (remove-if (lambda (x) 
                                (or (string-equal x (string names-from))
                                    (string-equal x (string values-from))))
                              all-names))
         (name-col (cl-tibble:tbl-col data names-from))
         (val-col (cl-tibble:tbl-col data values-from))
         (n-rows (get-nrow data)))

    ;; 2. Scan for unique output columns and group rows
    (let ((groups (make-hash-table :test #'equal)) ;; Key: ID-Values-List -> Value: Hash(Name -> Val)
          (unique-new-cols (make-hash-table :test #'equal))
          (groups-order (list))) ;; Preserve order of first appearance
      
      (let ((id-cols (mapcar (lambda (name) (cl-tibble:tbl-col data name)) id-names)))
        
        (dotimes (i n-rows)
          (let ((id-key (mapcar (lambda (col) (elt col i)) id-cols))
                (name-val (elt name-col i))
                (val-val (elt val-col i)))
            
            ;; Track column names
            (setf (gethash name-val unique-new-cols) t)
            
            ;; Grouping
            (let ((row-map (gethash id-key groups)))
              (unless row-map
                (setf row-map (make-hash-table :test #'equal))
                (setf (gethash id-key groups) row-map)
                (push id-key groups-order))
              ;; Assign value
              ;; TODO: Handle duplicates (aggregation) - M3 implies basic case
              (setf (gethash name-val row-map) val-val)))))
      
      (setf groups-order (nreverse groups-order))
      
      ;; 3. Construct Result
      ;; New columns: ID cols + Sorted Unique Names
      (let* ((sorted-new-cols (sort (alexandria:hash-table-keys unique-new-cols) #'string< :key #'string))
             (n-groups (length groups-order))
             (res-id-cols (mapcar (lambda (x) (make-array n-groups)) id-names))
             (res-val-cols (mapcar (lambda (x) (make-array n-groups)) sorted-new-cols)))
        
        ;; Fill vectors
        (loop for id-key in groups-order
              for i from 0
              do
              (let ((row-map (gethash id-key groups)))
                ;; Fill IDs
                (loop for id-val in id-key
                      for vec in res-id-cols
                      do (setf (aref vec i) id-val))
                
                ;; Fill Values
                (loop for col-name in sorted-new-cols
                      for vec in res-val-cols
                      do 
                      (let ((val (gethash col-name row-map :not-found)))
                        (if (eq val :not-found)
                            (setf (aref vec i) values-fill)
                            (setf (aref vec i) val))))))
        
        ;; Create Tibble
        (let ((args (list)))
          (loop for name in id-names
                for vec in res-id-cols
                do (push (intern (string-upcase name) "KEYWORD") args)
                   (push vec args))
          (loop for name in sorted-new-cols
                for vec in res-val-cols
                do (push (intern (string-upcase (string name)) "KEYWORD") args)
                   (push vec args))
          (apply #'cl-tibble:tibble (nreverse args)))))))

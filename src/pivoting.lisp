(in-package #:cl-tidyr)

(defun pivot-longer (data cols &key (names-to "name") (values-to "value") (values-drop-na nil))
  "Pivots data from wide to long."
  
  ;; 1. Identify Pivot Columns
  ;; cols is a list of selectors, e.g. (:x :y) or string names.
  ;; Use cl-dplyr:select to resolve them?
  ;; Issues: cl-dplyr:select returns a dataframe. I need the NAMES.
  ;; I can get names from the selected dataframe.
  (let* ((pivot-df (apply #'cl-dplyr:select data cols))
         (pivot-names (map 'list #'identity (cl-tibble:tbl-names pivot-df))) ;; Vector -> List
         (n-rows (get-nrow data)))
    
    ;; 2. Identify ID Columns (all others)
    ;; select(data, -cols)
    ;; How to do exclusion?
    ;; Get all names, subtract pivot-names.
    (let* ((all-names (map 'list #'identity (cl-tibble:tbl-names data)))
           (id-names (set-difference all-names pivot-names :test #'equal)))
      
      ;; 3. Construct New Data
      ;; We will iterate: Row -> PivotCol -> Create Entry
      ;; Number of new rows = n-rows * length(pivot-names)
      ;; minus dropped NA rows.
      
      ;; We need to build vectors for ID columns, names-to col, values-to col.
      (let ((new-id-cols (mapcar (lambda (x) (make-array 0 :fill-pointer 0 :adjustable t)) id-names))
            (new-key-col (make-array 0 :fill-pointer 0 :adjustable t))
            (new-val-col (make-array 0 :fill-pointer 0 :adjustable t)))
        
        ;; Prepare data access
        (let ((id-data-cols (mapcar (lambda (name) (cl-tibble:tbl-col data name)) id-names))
              (pivot-data-cols (mapcar (lambda (name) (cl-tibble:tbl-col data name)) pivot-names)))
          
          ;; Loop
          (dotimes (i n-rows)
            (loop for p-name in pivot-names
                  for p-col in pivot-data-cols
                  do 
                  (let ((val (elt p-col i)))
                    (unless (and values-drop-na (or (null val) (eq val :null)))
                      ;; Add row
                      ;; 1. Keys and Values
                      (vector-push-extend (string p-name) new-key-col)
                      (vector-push-extend val new-val-col)
                      
                      ;; 2. ID Columns (replicate current row i)
                      (loop for id-col in id-data-cols
                            for target-vec in new-id-cols
                            do (vector-push-extend (elt id-col i) target-vec)))))))
        
        ;; 4. Build Resulting Tibble
        ;; Combine: new-id-cols + names-to + values-to
        (let ((args (list)))
          ;; Add ID cols
          (loop for name in id-names
                for vec in new-id-cols
                do (push (intern (string-upcase name) "KEYWORD") args)
                   (push vec args))
          
          ;; Add Key Col
          (push (intern (string-upcase names-to) "KEYWORD") args)
          (push new-key-col args)
          
          ;; Add Value Col
          (push (intern (string-upcase values-to) "KEYWORD") args)
          (push new-val-col args)
          
          (apply #'cl-tibble:tibble (nreverse args)))))))

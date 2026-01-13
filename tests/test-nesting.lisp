(in-package #:cl-tidyr.tests)

(in-suite :cl-tidyr)

(test nest-basic
  "Test nest functionality"
  (let* ((df (cl-tibble:tibble :g (vector 1 1 2)
                               :x (vector "a" "b" "c")
                               :y (vector 10 20 30)))
         ;; Nest x and y into "data"
         (res (nest df :data :x :y)))
    
    ;; Should have 2 rows (g=1, g=2)
    (is (= 2 (length (cl-tibble:tbl-col res :G))))
    (is (cl-tibble:tbl-col res :G))
    (is (cl-tibble:tbl-col res :DATA))
    
    ;; Check content of nested column
    (let ((nested-col (cl-tibble:tbl-col res :DATA)))
      ;; First element should be a tibble with 2 rows ("a",10) and ("b",20)
      (let ((t1 (elt nested-col 0)))
        (is (= 2 (length (cl-tibble:tbl-col t1 :X))))
        ;; Assuming nrow still works on objects, if not I need to replace it there too.
        ;; Wait, cl-tibble:nrow is NOT exported. I should use (get-nrow t1) effectively or check column length
        ;; But get-nrow is internal. I'll use length of a known column.
        (is (equal "a" (elt (cl-tibble:tbl-col t1 :X) 0))))
      
      ;; Second element should be a tibble with 1 row ("c",30)
      (let ((t2 (elt nested-col 1)))
        (is (= 1 (length (cl-tibble:tbl-col t2 :X))))
         (is (equal "c" (elt (cl-tibble:tbl-col t2 :X) 0)))))))

(test unnest-basic
  "Test unnest functionality"
  (let* ((df (cl-tibble:tibble :g (vector 1 1 2)
                               :x (vector "a" "b" "c")))
         ;; Nest first
         (nested (nest df :data :x))
         ;; Unnest back
         (res (unnest nested :data)))
    
    ;; Should be back to 3 rows
    (is (= 3 (length (cl-tibble:tbl-col res :G))))
    
    ;; Check columns exist
    (is (cl-tibble:tbl-col res :G))
    (is (cl-tibble:tbl-col res :X))
    
    ;; Check values
    (let ((gs (cl-tibble:tbl-col res :G))
          (xs (cl-tibble:tbl-col res :X)))
      (is (= 1 (elt gs 0)))
      (is (equal "a" (elt xs 0)))
      (is (= 2 (elt gs 2)))
      (is (equal "c" (elt xs 2))))))

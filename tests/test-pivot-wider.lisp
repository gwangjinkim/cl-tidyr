(in-package #:cl-tidyr.tests)

(in-suite :cl-tidyr)

(test pivot-wider-basic
  "Test pivot-wider basic functionality"
  (let* ((df (cl-tibble:tibble :id (vector 1 1 2 2)
                               :key (vector "x" "y" "x" "y")
                               :val (vector 10 20 30 40)))
         (res (pivot-wider df :names-from :key :values-from :val)))
    
    ;; Should have 2 rows (id=1, id=2)
    ;; Columns: id, x, y
    (is (= 2 (length (cl-tibble:tbl-col res :ID))))
    (is (= 3 (length (cl-tibble:tbl-names res))))
    
    ;; Check values
    (let ((xs (cl-tibble:tbl-col res :X))
          (ys (cl-tibble:tbl-col res :Y)))
      (is (= 10 (elt xs 0)))
      (is (= 30 (elt xs 1)))
      (is (= 20 (elt ys 0)))
      (is (= 40 (elt ys 1))))))

(test pivot-wider-fill
  "Test pivot-wider with missing keys"
  (let* ((df (cl-tibble:tibble :id (vector 1 2)
                               :key (vector "x" "y")
                               :val (vector 10 20)))
         (res (pivot-wider df :names-from :key :values-from :val :values-fill 0)))
    
    ;; id 1 has x=10, y=missing (0)
    ;; id 2 has x=missing (0), y=20
    (let ((xs (cl-tibble:tbl-col res :X))
          (ys (cl-tibble:tbl-col res :Y)))
      (is (= 10 (elt xs 0)))
      (is (= 0 (elt xs 1)))
      (is (= 0 (elt ys 0)))
      (is (= 20 (elt ys 1))))))

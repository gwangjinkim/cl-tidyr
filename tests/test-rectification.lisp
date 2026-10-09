(in-package #:cl-tidyr.tests)

(in-suite :cl-tidyr)

(test expand-basic
  "Test expand functionality"
  (let* ((df (cl-tibble:tibble :x (vector "A" "A" "B")
                               :y (vector 1 2 1)))
         (res (expand df :x :y)))
    ;; Unique X: A, B. Unique Y: 1, 2.
    ;; Product: (A,1) (A,2) (B,1) (B,2) -> 4 rows
    (is (= 4 (length (cl-tibble:tbl-col res :X))))
    
    ;; Verify columns exist
    (is (cl-tibble:tbl-col res :X))
    (is (cl-tibble:tbl-col res :Y))
    
    ;; Verify content roughly (ordering might vary depending on implementation, 
    ;; but typically sorted by first col then second)
    ;; We can check that we have 4 unique rows
    ))

(test complete-basic
  "Test complete functionality"
  (let* ((df (cl-tibble:tibble :x (vector "A" "B")
                               :y (vector 1 2)
                               :val (vector 10 20)))
         ;; We have (A,1) and (B,2).
         ;; Expanding x and y gives (A,1), (A,2), (B,1), (B,2).
         ;; So we expect 4 rows.
         ;; (A,2) and (B,1) should have val=nil/NA.
         (res (complete df :x :y)))
    
    (is (= 4 (length (cl-tibble:tbl-col res :X))))
    
    ;; Check for the missing values
    ;; We need to find the row where X="A" and Y=2
    (let ((xs (cl-tibble:tbl-col res :X))
          (ys (cl-tibble:tbl-col res :Y))
          (vals (cl-tibble:tbl-col res :VAL))
          (found-missing nil))
      (dotimes (i 4)
        (let ((x (elt xs i))
              (y (elt ys i))
              (v (elt vals i)))
          (when (and (equal x "A") (= y 2))
            (is (na-p v))
            (setf found-missing t))))
      (is-true found-missing))))

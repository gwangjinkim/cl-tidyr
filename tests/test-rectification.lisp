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

(test tr1-grid-order-and-empty-prototypes
  (let ((slow (expand-grid :x #(2 1) :y #("b" "a")))
        (fast (expand-grid :x #(2 1) :y #("b" "a") :vary :fastest)))
    (is (equalp #(2 2 1 1) (cl-tibble:tbl-col slow :x)))
    (is (equalp #(2 1 2 1) (cl-tibble:tbl-col fast :x)))
    (is (equalp #(1 1 2 2) (cl-tibble:tbl-col (crossing :x #(2 1 2) :y #("b" "a")) :x))))
  (let ((empty (expand-grid :x (make-typed-column #() :int) :y #("a"))))
    (is (= 0 (cl-tibble:tbl-nrows empty)))
    (is (eq :int (col-type (cl-tibble:tbl-col empty :x)))))
  (is (= 1 (cl-tibble:tbl-nrows (expand-grid))))
  (signals error (expand-grid :x #(1) :x #(2))))

(test tr1-complete-duplicates-and-fill-mask
  (let* ((data (cl-tibble:tibble :x #(1 1 2) :y #("a" "a" "b") :v (vector 10 *na* 30)))
         (result (complete data :x :y '(:options :fill (:v 0) :explicit nil))))
    (is (= 5 (cl-tibble:tbl-nrows result)))
    (is (equalp #(10 0 0 30) (cl-tibble:tbl-col (complete (cl-tibble:tibble :x #(1 2) :y #("a" "b") :v #(10 30)) :x :y :fill '(:v 0)) :v)))
    (is (na-p (col-ref (cl-tibble:tbl-col result :v) 1)))))

(test tr1-vector-tools-and-scalar-false
  (is (equalp #(1 2 3 4 5) (full-seq #(1 3 5) 1)))
  (signals error (full-seq #(1d0 2.5d0) 1))
  (let* ((data (cl-tibble:tibble :x #("a" "b") :n #(0 2)))
         (result (uncount data :n :id "id")))
    (is (equalp #("x" "id") (cl-tibble:tbl-names result)))
    (is (equalp #("b" "b") (cl-tibble:tbl-col result :x)))
    (is (equalp #(1 2) (cl-tibble:tbl-col result :id))))
  (is (equalp #(nil t nil) (replace-na (make-typed-column (vector nil t *na*) :bool) nil))))

(test tr1-reserved-expansion-column-names
  (let ((data (cl-tibble:tibble :name-repair #(1 2) :unique #("a" "b") :fill #(3 4) :explicit #(5 6))))
    (is (= 4 (cl-tibble:tbl-nrows (expand data :name-repair :unique))))
    (is (= 4 (cl-tibble:tbl-nrows (complete data :fill :explicit))))
    (is (= 4 (cl-tibble:tbl-nrows (expand data :name-repair :unique '(:options :name-repair :minimal)))))))

(test tr1-nesting-list-type-and-null-order
  (let ((result (nesting :x (make-typed-column (vector #(1) #(1d0) nil) :list))))
    (is (= 3 (cl-tibble:tbl-nrows result)))
    (is (eq :int (col-type (col-ref (cl-tibble:tbl-col result :x) 0))))
    (is (eq :double (col-type (col-ref (cl-tibble:tbl-col result :x) 1))))
    (is (null (col-ref (cl-tibble:tbl-col result :x) 2)))))

(test tr1-pinned-root-character-collation
  (let ((result (crossing :x #("B" "á" "a" "b" "A"))))
    (is (equalp #("a" "A" "á" "b" "B") (cl-tibble:tbl-col result :x))))
  (is (equalp #(76 1 0 0) (cl-tidyr::%tr-collation-version)))
  (signals tidyr-error (cl-tidyr::%tr-string< (string (code-char 0)) "a")))

(test tr1-scalar-false-and-subsecond-sequences
  (let ((grid (expand-grid :x nil)))
    (is (= 1 (cl-tibble:tbl-nrows grid)))
    (is (eq :bool (col-type (cl-tibble:tbl-col grid :x))))
    (is (null (col-ref (cl-tibble:tbl-col grid :x) 0))))
  (is (= 0 (cl-tibble:tbl-nrows (uncount (cl-tibble:tibble :x #(1 2)) nil))))
  (signals tidyr-error (full-seq #(0d0 10.000005d0 20d0) 10d0 :tol 1d-6))
  (let* ((input (restore-column
                 (vector (local-time:unix-to-timestamp 0 :nsec 250000000)
                         (local-time:unix-to-timestamp 1 :nsec 250000000)) (make-prototype :datetime)))
         (result (full-seq input 0.25d0)))
    (is (eq :datetime (col-type result)))
    (is (= 5 (col-length result)))
    (is (equalp #(250000000 500000000 750000000 0 250000000)
                (map 'vector #'local-time:nsec-of result)))))

(test tr1-scalar-na-and-invalid-closure
  (let ((result (expand-grid :x *na*)))
    (is (= 1 (cl-tibble:tbl-nrows result)))
    (is (eq :bool (col-type (cl-tibble:tbl-col result :x))))
    (is (na-p (col-ref (cl-tibble:tbl-col result :x) 0))))
  (signals tidyr-error (expand-grid :x #'identity))
  (let* ((column (make-typed-column (vector #'identity) :list))
         (result (expand-grid :x column)))
    (is (eq #'identity (col-ref (cl-tibble:tbl-col result :x) 0)))))

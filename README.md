# cl-tidyr: Tidy Data for Common Lisp

`cl-tidyr` is a Common Lisp library inspired by R's `tidyr` package. It provides a set of tools to help you create **tidy data**, where:

1.  Every column is a variable.
2.  Every row is an observation.
3.  Every cell is a single value.

Built on top of `cl-tibble`, it brings the power of the "tidyverse" to Common Lisp data analysis.

## Installation

Clone the repository to your local-projects directory (e.g., `~/common-lisp/` or `~/.roswell/local-projects/`):

```bash
cd ~/common-lisp/
git clone https://github.com/yourusername/cl-tidyr.git
```

Load it via ASDF or Quicklisp:

```lisp
(ql:quickload :cl-tidyr)
```

## core Concepts

The library operates on **tibbles** (modern data frames). The API is designed to be functional and pipe-friendly using the `tidy` macro.

## Usage Guide

All examples assume you have loaded the package:

```lisp
(use-package :cl-tidyr)
(use-package :cl-tibble)
```

### 1. The `tidy` Macro (Chaining)

The `tidy` macro allows you to chain operations cleanly, passing the result of each step as the first argument to the next.

```lisp
(tidy data
  (step-1 args...)
  (step-2 args...))
```

### 2. Pivoting

Reshape your data layout.

#### `pivot-longer`
Converts columns into rows (wide to long). Useful when column names are actually values of a variable.

```lisp
(defparameter *wide* 
  (tibble :id (vector 1 2)
          :x (vector 10 20)
          :y (vector 30 40)))

;; Result: 4 rows, cols: ID, KEY, VAL
(tidy *wide*
  (pivot-longer (list :x :y) 
                :names-to "key" 
                :values-to "val"))
```

#### `pivot-wider`
Converts rows into columns (long to wide). Useful when a variable is spread across rows.

```lisp
(defparameter *long*
  (tibble :id (vector 1 2)
          :key (vector "x" "y")
          :val (vector 100 200)))

;; Result: 1 row, cols: ID, X, Y
(tidy *long*
  (pivot-wider :names-from :key 
               :values-from :val 
               :values-fill 0))
```

### 3. Missing Values

Handle missing data (`nil` or `:null`).

-   **`drop-na`**: Drop rows containing missing values.
-   **`replace-na`**: Replace missing values with specified constants.
-   **`fill`**: Fill missing values with the previous (or next) value.

```lisp
(defparameter *messy*
  (tibble :x (vector 1 nil 3)
          :y (vector "a" "b" nil)))

(tidy *messy*
  (fill :x :direction :down)        ;; Fills nil in X with 1
  (replace-na (list :y "missing"))  ;; Replaces nil in Y with "missing"
  (drop-na))                        ;; Drops any remaining rows with NAs
```

### 4. String Manipulation

Split and combine columns.

-   **`unite`**: Combine multiple columns into one string column.
-   **`separate`**: Split a single string column into multiple columns.

```lisp
(defparameter *dates*
  (tibble :year (vector 2020 2021)
          :month (vector 01 02)
          :day (vector 15 20)))

(tidy *dates*
  (unite "date" :year :month :day :sep "-") ;; "2020-1-15"
  (separate :date (list "y" "m" "d") :sep "-"))
```

### 5. Rectification

Ensure your data has all combinations of variables.

-   **`expand`**: Generates all combinations of unique values for specified columns.
-   **`complete`**: Adds missing combinations to the dataframe, filling remaining vars with `nil`.

```lisp
(defparameter *incomplete*
  (tibble :group (vector "A" "B")
          :item (vector 1 1)
          :val (vector 10 20)))

;; Missing combinations: (A, 1) exists, (B, 1) exists. 
;; Wait, purely implicit? 
;; Imagine (A,1) and (B,2). We want (A,2) and (B,1) too.

(tidy *incomplete*
  (complete :group :item))
```

### 6. Nesting (Advanced)

Group data into list-columns containing sub-tibbles.

-   **`nest`**: Nest columns into a tibble column.
-   **`unnest`**: Expand a list-column of tibbles back into rows.

```lisp
(defparameter *grouped*
  (tibble :g (vector 1 1 2)
          :x (vector "a" "b" "c")
          :y (vector 10 20 30)))

;; Collapse x and y into a single 'data' column for each 'g'
(defparameter *nested*
  (nest *grouped* :data :x :y))

;; Restore
(unnest *nested* :data)
```

## Contributing

Pull requests are welcome. Please ensure `make test` passes.

# cl-tidyr

`cl-tidyr` is a Common Lisp library for **tidy data reshaping**, part of the `cl-tidyverse` ecosystem. It provides a set of tools to change the shape (layout) of your data, handle missing values, and manage nested structures.

## Why cl-tidyr?

In Data Science, "Tidy Data" is a standard way of mapping the meaning of a dataset to its structure. In a tidy dataset:
1. Every column is a **variable**.
2. Every row is an **observation**.
3. Every cell is a **single value**.

Messy data often stores variables as column headers or combines multiple observations into one row. `cl-tidyr` helps you transform this "messy" data into "tidy" data, making it much easier to analyze with libraries like `cl-dplyr` and `cl-tibble`.

---

## Quick Reference for R Tidyverse Users

If you are coming from R, `cl-tidyr` will feel very familiar. Here is a lookup table for the most common functions:

| R tidyr | cl-tidyr | Purpose |
| :--- | :--- | :--- |
| `pivot_longer()` | `pivot-longer` | Wide to Long (Gather) |
| `pivot_wider()` | `pivot-wider` | Long to Wide (Spread) |
| `separate()` | `separate` | Split one column into many |
| `unite()` | `unite` | Combine many columns into one |
| `drop_na()` | `drop-na` | Remove rows with missing values |
| `replace_na()` | `replace-na` | Fill missing values with specific data |
| `fill()` | `fill` | Propagate values (last observation carried forward) |
| `nest()` | `nest` | Create list-columns of tibbles |
| `unnest()` | `unnest` | Flatten list-columns |
| `expand()` | `expand` | Generate all combinations of variables |
| `complete()` | `complete` | Fill in missing rows/combinations |

---

## Tutorial: Data Science with cl-tidyr

This tutorial is for Common Lisp developers who want to perform data cleaning and preparation.

### 1. Pivoting Data (Wide vs Long)

Imagine you have survey results where dates are column headers. This is "Wide" data.

```lisp
(defparameter *survey-wide*
  (cl-tibble:tibble :student '("Alice" "Bob")
                    :2025-01-01 '(90 85)
                    :2025-01-02 '(92 88)))

;; To analyze this over time, we want it "Long":
(pivot-longer *survey-wide* '(:2025-01-01 :2025-01-02)
              :names-to "date"
              :values-to "score")
;; => Result:
;; #<TIBBLE 4x3>
;; STUDENT  DATE        SCORE
;; "Alice"  "2025-01-01" 90
;; "Alice"  "2025-01-02" 92
;; "Bob"    "2025-01-01" 85
;; "Bob"    "2025-01-02" 88
```

### 2. Handling Missing Data (NA)

`cl-tidyr` uses a consistent standard for missing data via `cl-vctrs-lite:*na*`.

```lisp
(defparameter *messy-data*
  (cl-tibble:tibble :x (vector 1 *na* 3)
                    :y (vector "a" "b" nil)))

;; Drop rows with any NA
(drop-na *messy-data*)

;; Replace NA with a default
(replace-na *messy-data* '(:x 0 :y "unknown"))

;; Fill missing values (Last Observation Carried Forward)
(fill *messy-data* :x :direction :down)
```

### 3. The `tidy` Pipeline

Using the `tidy` macro, you can chain operations together elegantly:

```lisp
(tidy *survey-wide*
  (pivot-longer '(:2025-01-01 :2025-01-02) :names-to "date" :values-to "score")
  (separate "date" '("year" "month" "day") :sep "-")
  (drop-na :score))
```

---

## Shared selection helpers and expressions (TS1 / TS2)

`cl-tidyr` re-exports the same `cl-tidyselect` helper symbols used by
`cl-dplyr`: `starts-with`, `ends-with`, `contains`, `matches`, `num-range`,
`everything`, `last-col`, `all-of`, `any-of`, `one-of`, `where`, and
`vars-select-helpers`. The selection layer used by `pivot-longer` and `unite`
resolves names, zero-based positions, ordered unions, and exclusions.

These verbs are ordinary functions, so a helper needing column context is
passed as a zero-argument function. The verb calls it inside the data's
selection context:

```lisp
(cl-tidyr:pivot-longer df (lambda () (cl-tidyr:starts-with "x")))
(cl-tidyr:unite df "joined" (lambda () (cl-tidyr:starts-with "x")) :sep "_")
(cl-tidyr:pivot-longer df
  (lambda () (cl-tidyr:where
    (lambda (column) (eq :int (cl-vctrs-lite:col-type column))))))
;; Existing explicit column lists still work:
(cl-tidyr:pivot-longer df '("x_a" "x_b"))
```

The internal selector preserves types and the input row count even for
empty schemas. Named selector renaming is rejected in these reshape contexts,
matching R. The shared TS2 engine also accepts quoted operator/helper forms.
The reshaping algorithms' remaining parity work stays in TR1–TR5.

## Missing Value Standards (NA)

`cl-tidyr` is built on `cl-vctrs-lite`. To ensure robust performance:

1. **Detection**: TR1 helpers use column types: logical NIL is FALSE,
   list-cell NIL is NULL, and atomic NA/NaN are missing. The internal legacy
   `is-missing-p` helper remains for older reshape code; use explicit typed
   columns for the C1 contract.
2. **Production**: Functions like `complete` and `pivot-wider` will produce `*na*` by default for missing cells.

---

### Performance vs. NA Handling

`cl-tidyr` prioritizes semantic correctness and flexibility during the cleaning phase. This has implications for Common Lisp's **specialized vectors** (e.g., `(vector double-float)`):

- **Type Promotion**: To accommodate `*na*`, `cl-tidyr` promotes specialized numeric vectors to element-type `T`. Specialized vectors cannot store `*na*` without a type error.
- **The Recommended Workflow**:
  1. **Clean**: Use `cl-tidyr` verbs to reshape, drop, or fill missing data. The resulting tibble columns will typically be of type `T`.
  2. **Optimize**: Once the data is "tidy" and all NAs are removed or replaced with numeric defaults, coerce the columns back to specialized types for high-performance numeric processing.

```lisp
;; Example: Transitioning from Tidy to Optimized
(let* ((clean-df (drop-na messy-df :score))
       (scores (cl-tibble:tbl-col clean-df :score))
       (specialized-scores (coerce scores '(simple-array double-float (*)))))
  ;; High-performance processing here...
  )
```

---

## Installation

```lisp
(ql:quickload :cl-tidyr)
```

Requires: `cl-tibble`, `cl-tidyselect`, `cl-vctrs-lite`, `cl-ppcre`,
`alexandria`, `serapeum`, `cffi` and `local-time`; TR1 character sorting
also requires independent ICU 76.1 (see below).

## License

MIT

For example, `(pivot-longer df '(:to :x1 :x3))` selects an inclusive
column range. A standalone quoted helper call such as
`'(cl-tidyselect:starts-with "x")` also works, as do established selector
lists and helper thunks. :C, :UNION, :& and complement share dplyr's
selection rules. Predicates can inspect the actual frame through
`cl-tidyselect:peek-data`. Renaming remains prohibited in reshape contexts.

## Missing values and expansion (TR1)

| R | Common Lisp |
|---|---|
| `drop_na`, `replace_na` | `drop-na`, `replace-na` |
| `fill` | `.fill` (variadic selectors), `fill` (existing callable form) |
| `expand_grid`, `crossing`, `nesting` | `expand-grid`, `crossing`, `nesting` |
| `expand`, `complete` | `expand`, `complete` |
| `full_seq`, `uncount` | `full-seq`, `uncount` |
| `extract` | `extract` (superseded R API) |

Typed atomic/factor/date/list columns retain prototypes through empty results,
replication, completion and replacement. Scalar NIL is FALSE at public scalar
argument boundaries; list-cell NIL is NULL. Atomic NA and IEEE NaN are missing.
Untyped legacy numeric/string columns containing NIL keep their old missing
interpretation. Typed columns avoid that ambiguity. Existing CL:FILL calls on
ordinary sequences remain available.

```lisp
(cl-tidyr:expand-grid :x #(1 2) :y #("a" "b") :vary :fastest)
(cl-tidyr:crossing :x #(2 1 2) :y #("b" "a"))
(cl-tidyr:nesting :x #(1 1 2) :y #("a" "a" "b"))
(cl-tidyr:.fill df :x :y :direction :downup :by :group)
(cl-tidyr:complete df :x :y '(:options :fill (:value 0) :explicit nil))
(cl-tidyr:expand df '(:nesting :item :item_id) '(:as :year #(2024 2025)))
(cl-tidyr:uncount df :n :id "repeat")
```

Grid inputs use flat name/value pairs. `:name-repair` accepts the tibble repair
strategies; string keys disambiguate columns named vary/name-repair. `expand`
and `complete` preserve existing column-name calls. Computed expansion values
can be callbacks receiving the current input frame. Completion retains
original duplicate rows; `:explicit nil` replaces missing cells only in new
rows. Use `(:options ...)` controls when a column resembles an option.

`.fill` supports down/up/downup/updown and shared tidyselect selectors, with
helper thunks called in selection context. Its empty selection is unchanged.
`replace-na` accepts named table replacements, or a scalar replacement for a
vector, and rejects lossy casts. `uncount` accepts a named weight column,
scalar/vector or callback; grouped callbacks run per group, with original row
order retained. Its ID values are repetition counters 1..n for each source
row. `full-seq` checks absolute tolerance and preserves numeric, Date and the
shared UTC datetime representation, including tested fractional seconds.

Character expansion values use independent ICU 76.1 root collation, matching
the pinned R environment. Group-key blocks retain dplyr's C ordering. Regex
extraction uses the already pinned native PCRE2 10.47 engine. Missing or
incompatible libraries error; native functions never launch R or load libR.
The existing stringr ICU 71.1 engine remains separate.

For another machine, provide independent ICU 76.1 with
`CL_TIDYR_ICU_LIBRARY`, or run `scripts/bootstrap-icu.sh`. The script verifies
the source checksum and builds in the foreground; artifacts stay under
`.native/`. The current macOS Homebrew runtime was tested. The source-build
fallback passed shell syntax checks but was not executed, and Linux remains
unverified. ICU uses the Unicode-3.0 license; PCRE2 uses BSD-3-Clause.

TR1 is still partial. Packed matrix/frame columns need a shared C2 owner
extension; full expression-generated naming/splicing, base R `type.convert`
hex/complex/nonfinite breadth and some character coercions remain incomplete.
Explicit `:by nil` on grouped `.fill` currently differs from R's `.by=NULL`.
Foreign timezone attributes and precision beyond the shared nanosecond UTC
model are not represented. Later reshape milestones and existing public
migration proposals retain their gates.

Validation for this continuation: 141 native tidyr checks and 137 new R
conformance cases pass. The full ecosystem run passes 3832 checks and 2820
R cases; all 56 golden topics regenerate byte-identically.

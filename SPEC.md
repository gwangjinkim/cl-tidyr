# cl-tidyr Specification

`cl-tidyr` is a Common Lisp library designed to help users create "tidy data". This specification outlines the core functionalities, mimicking the API and behavior of the R `tidyr` package.

## Core Philosophy
1.  Every column is a variable.
2.  Every row is an observation.
3.  Every cell is a single value.

## 1. Pivoting

### 1.1 `pivot-longer`
"Lengthens" data, increasing the number of rows and decreasing the number of columns.
- **Args**:
    - `data`: The tibble to pivot.
    - `cols`: Columns to pivot (supports `cl-dplyr` selectors).
    - `names-to`: String/Symbol. Name of column for keys.
    - `values-to`: String/Symbol. Name of column for values.
    - `values-drop-na`: Boolean. If true, drops rows with nil values.

### 1.2 `pivot-wider`
"Widens" data, increasing the number of columns and decreasing the number of rows.
- **Args**:
    - `data`: The tibble.
    - `names-from`: Column(s) for new headers.
    - `values-from`: Column(s) for cell values.
    - `values-fill`: Default value for missing cells (default `nil`).

## 2. String Manipulation

### 2.1 `unite`
Combines multiple columns into one.
- **Args**: `data`, `col` (new name), `...` (columns), `sep` (default "_"), `remove` (default T), `na-rm` (default F).

### 2.2 `separate`
Splits a column into multiple.
- **Args**: `data`, `col`, `into` (list of names), `sep` (char or regex), `remove` (default T), `convert` (default NIL).

## 3. Missing Values

- `drop-na`: Drops rows with NAs.
- `replace-na`: Replaces NAs with values.
- `fill`: Fills NAs with previous/next values.

## 4. Rectification

- `expand`: Generates combinations of variables.
- `complete`: Exposes implicit missing values.

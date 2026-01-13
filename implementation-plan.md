# cl-tidyr: Implementation Plan

This document outlines the roadmap for building `cl-tidyr`, a Common Lisp library for data reshaping (pivoting) and cleaning, modeled after R's `tidyr`.

## Project Overview

**Goal**: Provide functions to help users create "tidy data":
1. Every column is a variable.
2. Every row is an observation.
3. Every cell is a single value.

**Dependencies**:
- `cl-tibble`: Core data structure.
- `cl-dplyr`: For column selection semantics (select helpers) and pipe compatibility (`->`).
- `cl-vctrs-lite`: For type-stable vector operations.
- `cl-ppcre`: For regex operations (needed for separate, extract, pivot_longer patterns).
- `alexandria` / `serapeum`: General utilities.

## Roadmap & Agents

We will split the development into 5 Agents, focusing on core functionality first.

### Agent 1: Infrastructure & String Verbs
**Goal**: Set up the project capability and implement string manipulation verbs.

- **Setup**: Create `cl-tidyr.asd`, `src/packages.lisp`, test suite infrastructure (`fiveam`).
- **Dependency Integration**: Ensure `cl-tibble` and `cl-dplyr` load correctly.
- **unite()**: Implement function to paste multiple columns into one key column.
- **separate()**: Implement function to split one column into multiple using a separator or regex.
- **Verify**: Basic tests for unite/separate.

### Agent 2: Pivot Longer (The Core)
**Goal**: Implement the ability to "melt" wide data into long format.

- **pivot_longer()**:
    - Args: `data`, `cols` (selection), `names_to`, `values_to`.
    - Handle simple case: gathering specific columns into Key/Value pairs.
    - Handle `values_drop_na` argument.
- **Verify**: Test on various wide tibbles.

### Agent 3: Pivot Wider (The Core)
**Goal**: Implement the ability to "cast" long data into wide format.

- **pivot_wider()**:
    - Args: `data`, `names_from`, `values_from`.
    - Logic: Identify unique keys, generate new columns, fill cells.
    - Handle `values_fill` (default value for missing cells).
- **Verify**: Test round-tripping data (longer -> wider -> longer).

### Agent 4: Missing Values
**Goal**: Comprehensive handling of NA/nil values.

- **drop_na()**: Drop rows containing NAs in specific columns.
- **replace_na()**: Replace NAs with specified values (by column).
- **fill()**: Fill NAs with previous/next values (locf/nocb).
- **Verify**: Tests with sparse data.

### Agent 5: Rectification & Expansion
**Goal**: Tools to complete missing data combinations.

- **expand()**: Generate all combinations of variables (crossing).
- **complete()**: Turn implicit missing values into explicit missing values (expand + join).
- **Verify**: Tests for generating sequences and grid expansions.

## Technical Considerations

- **Column Selection**: `pivot_longer` needs to accept `cl-dplyr`-style column selectors (e.g., `(select :start :end)`). We should leverage `cl-dplyr`'s existing logic if possible or replicate the resolve-selection logic.
- **Performance**: Pivoting involves heavy array restructuring. Utilizing `cl-tibble`'s internal column vectors directly will be faster than row-wise processing.
- **Nesting**: R's `tidyr` heavily depends on list-columns (`nest`/`unnest`). `cl-tibble` supports arbitrary objects, so we should eventually support this, but maybe as an "Agent 6" (Advanced) if needed.


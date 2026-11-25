#' Test whether values are absent from a set
#'
#' @param x Values to look up.
#' @param table Values against which to match.
#' @return A logical vector, with TRUE where x has no match in table.
#' @noRd
#'
#' @examples
#' 1 %not_in% 1:10
#' not_null(NULL)
`%not_in%` <- Negate(`%in%`)

#' Test whether an object has a value
#'
#' @param x Object to test.
#' @return TRUE for any object other than NULL.
#' @noRd
not_null <- Negate(is.null)

#' Identify values present in an object
#'
#' @param x Values to test.
#' @return The logical inverse of is.na(x).
#' @noRd
not_na <- Negate(is.na)

#' Removes the null from a vector
#'
#' @param x List of values that may contain NULL entries.
#' @return The list with NULL entries removed.
#' @noRd
#'
#' @examples
#' drop_nulls(list(1, NULL, 2))
drop_nulls <- function(x) {
  x[!sapply(x, is.null)]
}

#' If x is `NULL`, return y, otherwise return x
#'
#' @param x,y Two elements to test, one potentially `NULL`
#' @return x when it is present, otherwise y.
#'
#' @noRd
#'
#' @examples
#' NULL %||% 1
"%||%" <- function(x, y) {
  if (is.null(x)) {
    y
  } else {
    x
  }
}

#' If x is `NA`, return y, otherwise return x
#'
#' @param x,y Two elements to test, one potentially `NA`
#' @return x when it is non-missing, otherwise y.
#'
#' @noRd
#'
#' @examples
#' NA %|NA|% 1
"%|NA|%" <- function(x, y) {
  if (is.na(x)) {
    y
  } else {
    x
  }
}

#' Initialise a mutable container for session state
#'
#' @param ... Initial named values forwarded to shiny::reactiveValues().
#' @return A Shiny reactiveValues container.
#'
#' @noRd
rv <- function(...) shiny::reactiveValues(...)
#' Read Shiny reactive values into an ordinary list
#'
#' @param ... Arguments forwarded to shiny::reactiveValuesToList().
#' @return A list of the current reactive values.
#' @noRd
rvtl <- function(...) shiny::reactiveValuesToList(...)

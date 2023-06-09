% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/check.R
\name{rhub_check}
\alias{rhub_check}
\title{Check a package on R-hub}
\usage{
rhub_check(gh_url = NULL, platforms = NULL, r_versions = NULL, branch = NULL)
}
\arguments{
\item{gh_url}{GitHub URL of a package to check, or \code{NULL} to check
the package in the current directory.}

\item{platforms}{Platforms to use, a character vector. Use \code{NULL} to
select from a list in interactive sessions. See \code{\link[=rhub_platforms]{rhub_platforms()}}.}

\item{r_versions}{Which R version(s) to use for the platforms that
supports multiple R versions. This arguemnt is not implemented yet.}

\item{branch}{Branch to use to run R-hub. Defaults to the current
branch if \code{gh_url} is \code{NULL}. Otherwise defaults to \code{"main"}. Note that
this branch also need to include the \code{rhub.yaml} workflow file.}
}
\value{
TODO
}
\description{
Check a package on R-hub
}

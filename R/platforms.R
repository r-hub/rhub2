
get_platforms <- function() {
  url_platforms <- "https://raw.githubusercontent.com/r-hub/rhub2/v1/actions/rhub-setup/platforms.json"
  url_containers <- "https://r-hub.github.io/containers/manifest.json"
  ret <- synchronise(when_all(
    async_cached_http_get(url_platforms),
    async_cached_http_get(url_containers)
  ))
  ret
}

#' List R-hub platforms
#'
#' @return Data frame with columns:
#' * `name`: platform name. Use this in the `platforms` argument of
#'   [rhub_check()].
#' * `aliases`: alternative platform names. They can also be used in the
#'   `platforms` argument of [rhub_check()].
#' * `type`:  `"os"` or `"container"`.
#' * `os_type`: Linux, macOS or Windows currently.
#' * `container`: URL of the container image for container platforms.
#' * `github_os`: name of the OS on GitHub Actions for non-container
#'   platforms.
#' * `r_version`: R version string. If `"*"` then any supported R version
#'   can be selected for this platform.
#' * `os_name`: name of the operating system, including Linux distribution
#'   name and version for container actions.
#'
#' @export

rhub_platforms <- function() {
  ret <- get_platforms()
  platforms <- jsonlite::fromJSON(ret[[1]])
  containers <- jsonlite::fromJSON(ret[[2]], simplifyVector = FALSE)$containers

  res <- data_frame(
    name = platforms[["name"]],
    aliases = lapply(zip(platforms[["cran-names"]], platforms[["aliases"]]), unique),
    type = platforms[["type"]],
    os_type = platforms[["os-type"]],
    container = platforms[["container"]],
    github_os = platforms[["os"]],
    r_version = platforms[["r-version"]],
    os_name = NA_character_
  )

  wcnt <- res$type == "container"
  cnt_tags <- vcapply(containers, "[[", "tag")
  res$r_version[wcnt] <- vcapply(res$container[wcnt], function(x) {
    if (! x %in% cnt_tags) return(NA_character_)
    sess <- containers[[match(x, cnt_tags)]]$builds[[1]]$`sessionInfo()`
    strsplit(sess, "\n", fixed = TRUE)[[1]][1]
  })

  res$os_name[wcnt] <- vcapply(res$container[wcnt], function(x) {
    if (! x %in% cnt_tags) return(NA_character_)
    osr <- containers[[match(x, cnt_tags)]]$builds[[1]]$`/etc/os-release`
    osr <- strsplit(osr, "\n", fixed = TRUE)[[1]]
    pn <- grep("^PRETTY_NAME", osr, value = TRUE)[1]
    pn <- sub("^PRETTY_NAME=", "", pn)
    pn <- unquote(pn)
    pn
  })

  res <- res[order(res$type == "container", res$name), ]

  res <- add_class(res, "rhub2_platforms")
  res
}

#' @export

format.rhub2_platforms <- function(x, ...) {
  ret <- character()
  wvms <- which(x$type == "os")
  wcts <- which(x$type == "container")
  counter <- 1L
  grey <- cli::make_ansi_style("gray70", grey = TRUE)
  if (length(wvms)) {
    vm <- if (has_emoji()) "\U1F5A5 " else "[VM] "
    ret <- c(ret, cli::rule("Virtual machines"))
    for (p in wvms) {
      ret <- c(
        ret,
        paste0(
          format(counter, width = 2), " ", vm, " ",
          cli::style_bold(cli::col_blue(x$name[p]))
        ),
        if (x$r_version[p] == "*") {
          grey(paste0("   All R versions on GitHub Actions ", x$github_os[p]))
        } else {
          x$r_version
        }
      )
      counter <- counter + 1L
    }
  }
  if (length(wcts)) {
    if (length(ret)) ret <- c(ret, "")
    ret <- c(ret, cli::rule("Containers"))
    for (p in wcts) {
      ct <- if (has_emoji()) "\U1F40B" else "[CT] "
      rv <- x$r_version[p]
      os <- x$os_name[p]
      al <- sort(unique(x$aliases[[p]]))
      al <- if (length(al)) {
        grey(paste0("  [", paste(al, collapse = ", "), "]"))
      } else {
        ""
      }
      ret <- c(
        ret,
        paste0(
          format(counter, width = 2), " ", ct, " ",
          cli::style_bold(cli::col_blue(x$name[p])),
          al
        ),
        grey(paste0(
          "   ",
          if (!is.na(rv)) rv,
          if (!is.na(rv) && !is.na(os)) " on ",
          if (!is.na(os)) os
        )),
        cli::style_italic(grey(paste0("   ", x$container[p])))
      )
      counter <- counter + 1L
    }
  }

  ret
}

#' @export

print.rhub2_platforms <- function(x, ...) {
  writeLines(cli::ansi_strtrim(format(x, ...)))
}

#' @export

`[.rhub2_platforms` <- function(x, i, j, drop = FALSE) {
  class(x) <- setdiff(class(x), "rhub2_platforms")
  NextMethod("[")
}

#' @export

summary.rhub2_platforms <- function(object, ...) {
  class(object) <- c("rhub2_platforms_summary", class(object))
  object
}

#' @export

format.rhub2_platforms_summary <- function(x, ...) {
  num <- format(seq_len(nrow(x)))
  icon <- if (!has_emoji()) {
    ifelse(x$type == "os", "[VM]", "[CT]")
  } else {
    ifelse(x$type == "os", "\U1F5A5", "\U1F40B")
  }
  name <- cli::style_bold(cli::col_blue(x$name))
  rv <- abbrev_version(x$r_version)
  os <- ifelse(
    is.na(x$os_name),
    paste0(x$github_os, " on GitHub"),
    x$os_name
  )

  lines <- paste(
    ansi_align_width(num),
    ansi_align_width(icon),
    ansi_align_width(name),
    ansi_align_width(rv),
    ansi_align_width(os)
  )

  trimws(lines, which = "right")
}

#' @export

print.rhub2_platforms_summary <- function(x, ...) {
  writeLines(cli::ansi_strtrim(format(x, ...)))
}

abbrev_version <- function(x) {
  sel <- grepl("^R Under development", x)
  x[sel] <- sub("R Under development [(]unstable[)]", "R-devel", x[sel])

  sel <- grepl("R version [0-9.]+ Patched", x)
  x[sel] <- sub("R version ([0-9.]+) Patched", "R-\\1 (patched)", x[sel])

  sel <- grepl("R version [0-9.]+", x)
  x[sel] <- sub("R version ([0-9.]+)", "R-\\1", x[sel])

  x[x == "*"] <- "R-* (any version)"

  x
}

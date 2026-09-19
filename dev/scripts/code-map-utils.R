# Development-only utilities: no package/runtime exports or code execution.
code_map_inputs <- function() sort(c("DESCRIPTION", "NAMESPACE",
  list.files("R", pattern = "\\.R$", full.names = TRUE),
  "dev/architecture/reviewed-call-bridges.json"))
code_map_hash <- function(path) {
  # Normalize line endings so a Git LF/CRLF conversion alone is not semantic drift.
  text <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  unclass(as.character(openssl::sha256(charToRaw(enc2utf8(text)))))
}
code_map_fresh <- function(map) {
  files <- vapply(map$inputs, `[[`, character(1), "file")
  identical(files, code_map_inputs()) && all(vapply(map$inputs, function(x)
    file.exists(x$file) && identical(code_map_hash(x$file), x$sha256), logical(1)))
}
code_map_neighborhood <- function(map, symbol) {
  Filter(function(x) identical(x$from, symbol) || identical(x$to, symbol), map$edges)
}
code_map_bridge <- function(edge) {
  lines <- readLines(edge$file, warn = FALSE)
  at <- grep(edge$anchor, lines, fixed = TRUE)
  if (length(at) != 1L) stop("Bridge anchor missing or ambiguous: ", edge$anchor)
  c(edge, list(line = at, evidence = "reviewed-source-bridge"))
}

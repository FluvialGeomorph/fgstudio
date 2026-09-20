# Run from the repository root after building pkgdown. Read-only, no network.
# xml2 is a pkgdown dependency; these checks concern generated docs, not app runtime.
pages <- unique(c("docs/index.html", "docs/articles/index.html",
  list.files("docs/articles", pattern = "\\.html$", full.names = TRUE)))
checked <- 0L
for (page in pages) {
  doc <- xml2::read_html(page)
  links <- unique(xml2::xml_attr(xml2::xml_find_all(doc, "//a[@href]"), "href"))
  for (link in links) {
    if (grepl("^([[:alpha:]][[:alnum:]+.-]*:|//)", link)) next
    bits <- strsplit(link, "#", fixed = TRUE)[[1]]
    target <- sub("\\?.*$", "", bits[1])
    target <- if (!nzchar(target)) page else file.path(dirname(page), URLdecode(target))
    if (dir.exists(target)) target <- file.path(target, "index.html")
    if (!file.exists(target)) stop("Missing local target: ", page, " -> ", link)
    if (length(bits) > 1L && nzchar(bits[2]) && grepl("\\.html$", target)) {
      ids <- xml2::xml_attr(xml2::xml_find_all(xml2::read_html(target), "//*[@id]"), "id")
      if (!URLdecode(bits[2]) %in% ids) stop("Missing anchor: ", page, " -> ", link)
    }
    checked <- checked + 1L
  }
}
articles <- tools::file_path_sans_ext(list.files("vignettes", pattern = "\\.Rmd$"))
home <- xml2::read_html("docs/index.html")
nav <- xml2::xml_attr(xml2::xml_find_all(home, "//nav//a[@href]"), "href")
for (article in articles) {
  stopifnot(file.exists(file.path("docs/articles", paste0(article, ".html"))),
    file.exists(file.path("docs/articles", paste0(article, ".md"))),
    paste0("articles/", article, ".html") %in% nav)
}
stopifnot(file.exists("docs/llms.txt"))
cat("Validated", checked, "local links across", length(pages), "pages and",
  length(articles), "article navigation/text exports.\n")

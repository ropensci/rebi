# utils

# base uri
base_uri <- function() "http://www.ebi.ac.uk"

# rest path
rest_path <- function() "europepmc/webservices/ver4.5.2/rest"
# check data sources
supported_data_src <- c("agr", "cba", "ctx", "eth", "hir", "med", "nbk", "pat",
                        "pmc")

# default batch size
batch_size <- function() 1000


# Common methods:

# Implementing GET method and json parser for EPMC
rebi_GET <- function(path = NULL, query = NULL, ...) {
  if (is.null(path) && is.null(query))
    stop("Nothing to search")
  # call api
  req <- httr::GET(base_uri(), path = path, query = query)
  # check for http status
  httr::stop_for_status(req)
  # load json into r
  out <- httr::content(req, "text")
  # valid json
  if(!jsonlite::validate(out))
    stop("Upps, nothing to parse, please check your query")
  doc <- jsonlite::fromJSON(out)
  if (!exists("doc"))
    stop("No json to parse", call. = FALSE)
  doc
}

# build query
build_query <- function(query, page, batch_size, ...){
  list(query = query,
       format = "json",
       page = page,
       pageSize = batch_size,
       ...)
}

# Calculate pages. Each page consists of 25 records.
rebi_pageing <- function(hitCount, pageSize) {
  if (all.equal((hitCount / pageSize), as.integer(hitCount / pageSize)) == TRUE) {
    1:(hitCount / pageSize)
  } else {
    1:(hitCount / pageSize + 1)
  }
}

# make paths according to limit and request methods
make_path <- function(hit_count = NULL, limit = NULL, ext_id = NULL,
                      data_src = NULL, req_method = NULL, type = NULL) {
  limit <- as.integer(limit)
  limit <- ifelse(hit_count <= limit, hit_count, limit)
  if (limit > batch_size()) {
    tt <- chunks(limit)
    paths <- lapply(1:(tt$page_max - 1), function(x)
      paste(c(rest_path(), data_src, ext_id, req_method, type, x, batch_size(), "json"), collapse ="/"))
    paths <- append(paths, list(
      paste(c(rest_path(), data_src, ext_id, req_method, type, tt$page_max, tt$last_chunk, "json"), collapse ="/")
    ))
  } else {
    paths <- paste(c(rest_path(), data_src, ext_id, req_method, type, 1, limit, "json"), collapse ="/")
  }
  paths
}

make_queries <- function(hit_count = hit_count, limit = limit, query = query) {
  limit <- as.integer(limit)
  limit <- ifelse(hit_count <= limit, hit_count, limit)
  if (limit > batch_size()) {
    tt <- chunks(limit)
    queries <-
      lapply(1:(tt$page_max - 1), build_query, batch_size = batch_size(), query = query)
    queries <-
      append(queries, list(build_query(query = query, page = tt$page_max, batch_size = tt$last_chunk)
      ))
  } else {
    queries <-list(build_query(page = 1, query = query, batch_size = limit
      ))
  }
  queries
}

# calculate number of page chunks needed in accordance with limit param
chunks <- function(limit, ...) {
  if (all.equal(limit / batch_size(), as.integer(limit / batch_size())) == TRUE) {
    page_max <- limit / batch_size()
    last_chunk <- batch_size()
  } else {
    page_max <- as.integer(limit / batch_size()) + 1
    last_chunk <- limit - ((page_max - 1) * batch_size())
  }
  list(page_max = page_max, last_chunk = last_chunk)
}


# fix to remove columns that cannot be easily flatten from the data.frame
fix_list <- function(x){
  if(!is.null(x))
    tmp <- plyr::ldply(x, is.list)
  tmp[tmp$V1 == TRUE, ".id"]
}


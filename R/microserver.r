#' Default http server configuration for libuv hook.
#'
#' @param routes list. A named list of routes, with a handler
#'    function for each route. The first unnamed route will be used
#'    as the root. If none is provided, just a 404 status will be returned.
#' @examples
#' \dontrun{
#'   http_server(list('/ping' = function(params, query) 'Hello world!',
#'                    function(params, query) 'Invalid route.'))
#' }
http_server <- function(routes) {
  function(req) {
    params <- extract_params_from_request(req)
    query  <- extract_query_from_request(req)
    route  <- determine_route(routes, req$PATH_INFO)
    if (is.microserver_response(route)) return(unclass(route))
    environment(route) <- list2env(list(server_env = function() .microserver_env), parent = environment(route))
    result <- route(params, query)
    if (is.microserver_response(result)) unclass(result)
    else unclass(microserver_response(result))
  }
}


#' Minimal function for opening a socket and accepting/responding to
#' requests.
#'
#' @param routes list. A named list of routes.
#' @param port integer. The default is 8103.
#' @importFrom httpuv startServer stopServer service
#' @export
run_server <- function(routes, port = 8103, decorators = NULL) {
  if (!is.null(decorators)) {
    stopifnot(is.list(decorators))
    stopifnot(all(sapply(decorators, is.function)))
    .microserver_env[['__decorators']] <- decorators
    on.exit(.microserver_env[['__decorators']] <- NULL, add = TRUE)
  }

  # A list of default HTTUPV callbacks
  httpuv_callbacks <- list(
    onHeaders = function(req) { NULL },
    call = http_server(routes),
    onWSOpen = function(ws) {
      # print('opening websocket')
    }
  )

  server_id <- httpuv::startServer("0.0.0.0", port, httpuv_callbacks)
  on.exit({ httpuv::stopServer(server_id) }, add = TRUE)

  repeat {
    httpuv::service(1)
    if (!is.null(.microserver_env[['__decorators']])) {
      lapply(.microserver_env[['__decorators']], function(decorator) decorator(.microserver_env))
    }
    clean_envir(.microserver_env, exceptions = c('__decorators'))
    Sys.sleep(0.001)
  }
}

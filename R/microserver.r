#' Default http server configuration for libuv hook.
#' 
#' @param routes list. A named list of routes, with a handler
#'    function for each route. The first unnamed route will be used
#'    as the root. In none is provided, just a 404 status will be returned.
#' @seealso \link{\code{parse_routes}}
#' @examples
#' \dontrun{
#'   http_server(list('/ping' = function(params, query) 'Hello world!',
#'                    function(params, query) 'Invalid route.'))
#' }
http_server <- function(routes) {
  function(req) {
    params <- extract_params_from_request(req)
    query <- extract_query_from_request(req)
    route <- determine_route(routes, req$PATH_INFO)
    body <- route(params, query)
    if (is.microserver_response(body)) unclass(body)
    else unclass(microserver_response(body))
  }
}


#' Minimal function for opening a socket and accepting/responding to
#' requests.
#'
#' @param port integer. The default is 8103.
#' @importFrom httpuv startServer
#' @importFrom httpuv stopServer
#' @export
run_server <- function(routes, port = 8103) {
  require(httpuv)

  # A list of default HTTUPV callbacks
  httpuv_callbacks <- list(
    onHeaders = function(req) { NULL },
    call = http_server(routes),
    onWSOpen = function(ws) {
      # print('opening websocket')
    }
  )

  server_id <- startServer("0.0.0.0", port, httpuv_callbacks)
  on.exit({ stopServer(server_id) })

  repeat {
    service(1)
    Sys.sleep(0.001)
  }
}


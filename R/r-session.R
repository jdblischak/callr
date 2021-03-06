
#' External R Session
#'
#' A permanent R session that runs in the background. This is an R6 class
#' that extends the [processx::process] class.
#'
#' The process is started at the creation of the object, and then it can
#' be used to evaluate R function calls, one at a time.
#'
#' @section Usage:
#' ```
#' rs <- r_session$new(options = r_session_options(), wait = TRUE,
#'                      wait_timeout = 3000)
#'
#' rs$run(func, args = list())
#' rs$run_with_output(func, args = list())
#' rs$call(func, args = list())
#'
#' rs$poll_process(timeout)
#'
#' rs$get_state()
#' rs$get_running_time()
#'
#' rs$read()
#' rs$close(grace = 1000)
#'
#' rs$traceback()
#' rs$debug()
#' rs$attach()
#' ```
#'
#' @section Arguments:
#' * `options`: A list of options created via [r_session_options()].
#' * `wait`: Whether to wait for the R process to start and be ready
#'   for running commands.
#' * `wait_timeout`: Timeout for waiting for the R process to start,
#'   in milliseconds.
#' * `func`: Function object to call in the background R process.
#'   Please read the notes for the similar argument of [r()]
#' * `args`: Arguments to pass to the function. Must be a list.
#' * `timeout`: Timeout period in milliseconds.
#' * `grace`: Grace period in milliseconds, to wait for the subprocess to
#'   exit cleanly, after its standard input is closed. If the process is
#'   still running after this period, it will be killed.
#'
#' @section Details:
#' `r_session$new()` creates a new R background process. It can wait for the
#' process to start up (`wait = TRUE`), or return immediately, i.e. before
#' the process is actually ready to run. In the latter case you may call
#' `rs$poll_process()` to make sure it is ready.
#'
#' `rs$run()` is similar to [r()], but runs the function in the `rs` R
#' session. It throws an error if the function call generated an error in
#' the child process.
#'
#' `rs$run_with_output()` is similar to `$run()`, but returns the standard
#' output and error of the child process as well. It does not throw on
#' errors, but returns a non-zero `error` member in the result list.
#'
#' `rs$call()` starts running a function in the background R session, and
#' returns immediately. To check if the function is done, call the
#' `poll_process()` method.
#'
#' `rs$poll_process()` polls the R session with a timeout. If the session
#' has finished the computation, it returns with `"ready"`. If the timeout
#' is reached, it returns with `"timeout"`.
#'
#' `rs$get_state()` return the state of the R session. Possible values:
#' * `"starting"`: starting up,
#' * `"idle"`: ready to compute,
#' * `"busy"`: computing right now,
#' * `"finished"`: the R process has finished.
#'
#' `rs$get_running_time()` returns the elapsed time since the R process
#' has started, and the elapsed time since the current computation has
#' started. The latter is NA if there is no active computation.
#'
#' `rs$read()` reads an event from the child process, if there is one
#' available. Events might signal that the function call has finished,
#' or they can be progress report events.
#'
#' `rs$close()` terminates the current computation and the R process.
#' The session object will be in `"finished"` state after this.
#'
#' `rs$traceback() can be used after an error in the R subprocess. It is
#' equivalent to the [traceback()] call, but it is performed in the
#' subprocess.
#'
#' `rs$debug()` is an interactive debugger to inspect the dumped frames
#' in the subprocess, after an error. See more at [r_session_debug].
#'
#' `rs$attach()` is an experimental function that provides a REPL
#' (Read-Eval-Print-Loop) to the subprocess.
#'
#' @name r_session
#' @examples
#' \dontrun{
#' rs <- r_ression$new()
#'
#' rs$run(function() 1 + 2)
#'
#' rs$call(function() Sys.sleep(1))
#' rs$get_state()
#'
#' rs$poll_process(-1)
#' rs$get_state()
#' rs$read()
#' }
NULL


#' @export

r_session <- R6::R6Class(
  "r_session",
  inherit = processx::process,

  public = list(
    initialize = function(options = r_session_options(), wait = TRUE,
                          wait_timeout = 3000)
      rs_init(self, private, super, options, wait, wait_timeout),

    read = function()
      rs_read(self, private),
    close = function(grace = 1000)
      rs_close(self, private, grace),

    call = function(func, args = list())
      rs_call(self, private, func, args),
    run_with_output = function(func, args = list())
      rs_run_with_output(self, private, func, args),
    run = function(func, args = list())
      rs_run(self, private, func, args),

    get_state = function()
      rs_get_state(self, private),
    get_running_time = function()
      rs_get_running_time(self, private),

    poll_process = function(timeout)
      rs_poll_process(self, private, timeout),

    traceback = function()
      rs_traceback(self, private),
    debug = function()
      rs_debug(self, private),

    attach = function()
      rs_attach(self, private),

    finalize = function() {
      unlink(private$tmp_output_file)
      unlink(private$tmp_error_file)
      unlink(private$options$tmp_files, recursive = TRUE)
      if ("finalize" %in% ls(super)) super$finalize()
    },
    print = function(...) {
      cat(
        sep = "",
        "R SESSION, ",
        if (self$is_alive()) {
          paste0("alive, ", self$get_state(), ", ")
        } else {
          "finished, "
        },
        "pid ", self$get_pid(), ".\n")
      invisible(self)
    }
  ),

  private = list(
    options = NULL,
    state = NULL,
    started_at = NULL,
    fun_started_at = as.POSIXct(NA),
    pipe = NULL,

    tmp_output_file = NULL,
    tmp_error_file = NULL,

    func_file = NULL,
    res_file = NULL,

    get_result_and_output = function()
      rs__get_result_and_output(self, private),
    report_back = function(code, text = "")
      rs__report_back(self, private, code, text),
    write_for_sure = function(text)
      rs__write_for_sure(self, private, text),
    parse_msg = function(msg)
      rs__parse_msg(self, private, msg),
    attach_wait = function()
      rs__attach_wait(self, private)
  )
)

rs_init <- function(self, private, super, options, wait, wait_timeout) {

  options$func <- options$func %||% function() { }
  options$args <- list()
  options$load_hook <- session_load_hook(options$load_hook)

  options <- convert_and_check_my_args(options)
  options <- setup_context(options)
  options <- setup_r_binary_and_args(options, script_file = FALSE)

  private$options <- options

  with_envvar(
    options$env,
    do.call(super$initialize, c(list(options$bin, options$real_cmdargs,
      stdin = "|", stdout = "|", stderr = "|", poll_connection = TRUE),
      options$extra))
  )

  ## Make child report back when ready
  private$report_back(201, "ready to go")

  private$pipe <- self$get_poll_connection()

  private$started_at <- Sys.time()
  private$state <- "starting"

  if (wait) {
    timeout <- wait_timeout
    have_until <- Sys.time() + as.difftime(timeout / 1000, units = "secs")
    pr <- self$poll_io(timeout)
    out <- ""
    err <- ""
    while (any(pr == "ready")) {
      if (pr["output"] == "ready") out <- paste0(out, self$read_output())
      if (pr["error"] == "ready") err <- paste0(err, self$read_error())
      if (pr["process"] == "ready") break
      timeout <- as.double(have_until - Sys.time(), units = "secs") * 1000
      pr <- self$poll_io(as.integer(timeout))
    }

    if (pr["process"] == "ready") {
      self$read()
    } else if (pr["process"] != "ready") {
      cat("stdout:]\n", out, "\n")
      cat("stderr:]\n", err, "\n")
      throw(new_error("Could not start R session, timed out"))
    }
  }

  invisible(self)
}

rs_read <- function(self, private) {
  out <- processx::processx_conn_read_lines(private$pipe, 1)
  if (!length(out)) {
    if (processx::processx_conn_is_incomplete(private$pipe)) return()
    if (self$is_alive()) {
      self$kill()
      out <- "502 R session closed the process connection, killed"
    } else if (identical(es <- self$get_exit_status(), 0L)) {
      out <- "500 R session finished cleanly"
    } else {
      out <- paste0("501 R session crashed with exit code ", es)
    }
  }
  if (length(out)) private$parse_msg(out)
}

rs_close <- function(self, private, grace) {
  processx::processx_conn_close(self$get_input_connection())
  self$poll_process(grace)
  self$kill()
  self$wait(1000)
  if (self$is_alive()) throw(new_error("Could not kill background R session"))
  private$state <- "finished"
  private$fun_started_at <- as.POSIXct(NA)
  processx::processx_conn_close(private$pipe)
  processx::processx_conn_close(self$get_output_connection())
  processx::processx_conn_close(self$get_error_connection())
}

rs_call <- function(self, private, func, args) {

  ## We only allow a new command if the R session is idle.
  ## This allows keeping a clean state
  ## TODO: do we need a state at all?
  if (private$state == "starting") throw(new_error("R session not ready yet"))
  if (private$state == "finished") throw(new_error("R session finished"))
  if (private$state == "busy") throw(new_error("R session busy"))

  ## Save the function in a file
  private$options$func <- func
  private$options$args <- args
  private$options$func_file <- save_function_to_temp(private$options)
  private$options$result_file <- tempfile()
  private$options$tmp_files <-
    c(private$options$tmp_files, private$options$func_file,
      private$options$result_file)

  ## Maybe we need to redirect stdout / stderr
  re_stdout <- if (is.null(private$options$stdout)) {
    private$tmp_output_file <- tempfile()
  }
  re_stderr <- if (is.null(private$options$stderr)) {
    private$tmp_error_file <- tempfile()
  }

  pre <- rs__prehook(re_stdout, re_stderr)
  post <- rs__posthook(re_stdout, re_stderr)

  ## Run an expr that loads it, in the child process, with error handlers
  expr <- make_vanilla_script_expr(private$options$func_file,
                                   private$options$result_file,
                                   private$options$error,
                                   pre_hook = pre, post_hook = post,
                                   messages = TRUE)
  cmd <- paste0(deparse(expr), "\n")

  ## Write this to stdin
  private$write_for_sure(cmd)
  private$fun_started_at <- Sys.time()

  ## Report back when done
  report_str <- paste0("done ", basename(private$options$result_file))
  private$report_back(200, report_str)

  private$state <- "busy"
}

rs_run_with_output <- function(self, private, func, args) {
  self$call(func, args)

  go <- TRUE
  res <- NULL

  while (go) {
    ## TODO: why is this in a tryCatch?
    res <- tryCatch(
      { processx::poll(list(private$pipe), -1)
        msg <- self$read()
        if (is.null(msg)) next
        if (msg$code == 200 || (msg$code >= 500 && msg$code < 600)) {
          return(msg)
        }
        if (msg$code == 301) {
          rs__handle_condition(msg$message)
        }
      },
      interrupt = function(e) {
        self$interrupt()
        ## The R process will catch the interrupt, and then save the
        ## error object to a file, but this might still take some time,
        ## so we need to poll here. If the bg process ignores
        ## interrupts, then we kill it.
        ps <- processx::poll(list(private$pipe), 1000)[[1]]
        if (ps == "timeout") {
          self$kill()
        } else {
          res <<- self$read()
          go <<- FALSE
        }
        iconn <- structure(
          list(message = "Interrupted"),
          class = c("interrupt", "condition"))
        signalCondition(iconn)
        cat("\n")
        invokeRestart("abort")
    })
  }
  res
}

rs_run <- function(self, private, func, args) {
  res <- rs_run_with_output(self, private, func, args)
  if (is.null(res$error)) {
    res$result
  } else{
    res$stdout <- paste0(res$stdout, self$read_output())
    res$stderr <- paste0(res$stderr, self$read_error())
    throw(res$error)
  }
}

rs_get_state <- function(self, private) {
  private$state
}

rs_get_running_time <- function(self, private) {
  now <- Sys.time()
  finished <- private$state == "finished"
  c(total = if (finished) now - private$started_at else as.POSIXct(NA),
    current = now - private$fun_started_at)
}

rs_poll_process <- function(self, private, timeout) {
  processx::poll(list(self$get_poll_connection()), timeout)[[1]]
}

rs_traceback <- function(self, private) {
  ## TODO: get rid of magic number 12
  traceback(utils::head(self$run(function() traceback()), -12))
}

rs_debug <- function(self, private) {
  hasdump <- self$run(function() {
    ! is.null(as.environment("tools:callr")$`__callr_data__`$.Last.dump)
  })
  if (!hasdump) stop("Can't find dumped frames, nothing to debug")

  help <- function() {
    cat("Debugging in process ", self$get_pid(),
        ", press CTRL+C (ESC) to quit. Commands:\n", sep = "")
    cat("  .where       -- print stack trace\n",
        "  .inspect <n> -- inspect a frame, 0 resets to .GlobalEnv\n",
        "  .help        -- print this message\n",
        "  <cmd>        -- run <cmd> in frame or .GlobalEnv\n\n", sep = "")
  }

  translate_cmd <- function(cmd) {
    if (cmd == ".where") {
      traceback(tb)
      if (frame) cat("Inspecting frame", frame, "\n")
      NULL

    } else if (cmd == ".help") {
      help()
      NULL

    } else if (grepl("^.inspect ", cmd)) {
      newframe <- as.integer(strsplit(cmd, " ")[[1]][[2]])
      if (is.na(newframe)) {
        message("Cannot parse frame number")
      } else {
        frame <<- newframe
      }
      NULL

    } else {
      cmd
    }
  }

  help()
  tb <- self$traceback()
  frame <- 0L

  while (TRUE) {
    cat("\n")
    prompt <- paste0(
      "RS ", self$get_pid(),
      if (frame) paste0(" (frame ", frame, ")"), " > ")
    cmd <- rs__attach_get_input(prompt)
    cmd2 <- translate_cmd(cmd)
    if (is.null(cmd2)) next

    update_history(cmd)

    ret <- self$run_with_output(function(cmd, frame) {
      dump <- as.environment("tools:callr")$`__callr_data__`$.Last.dump
      envir <- if (!frame) .GlobalEnv else dump[[frame + 12L]]
      eval(parse(text = cmd), envir = envir)
    }, list(cmd = cmd, frame = frame))
    cat(ret$stdout)
    cat(ret$stderr)
    if (!is.null(ret$error)) print(ret$error)
    print(ret$result)
  }
  invisible()
}

rs_attach <- function(self, private) {
  out <- self$get_output_connection()
  err <- self$get_error_connection()
  while (nchar(x <- processx::processx_conn_read_chars(out))) cat(x)
  while (nchar(x <- processx::processx_conn_read_chars(err))) cat(bold(x))
  tryCatch({
    while (TRUE) {
      cmd <- rs__attach_get_input(paste0("RS ", self$get_pid(), " > "))
      update_history(cmd)
      private$write_for_sure(paste0(cmd, "\n"))
      private$report_back(202, "done")
      private$attach_wait()
    } },
    interrupt = function(e) { self$interrupt(); invisible() }
  )
}

## Internal functions ----------------------------------------------------

rs__attach_get_input <- function(prompt) {
  cmd <- readline(prompt = prompt)
  while (! is_complete_expression(cmd)) {
    cmd <- paste0(cmd, sep = "\n", readline(prompt = "+ "))
  }
  cmd
}

rs__attach_wait <- function(self, private) {
  out <- self$get_output_connection()
  err <- self$get_error_connection()
  pro <- private$pipe
  while (TRUE) {
    pr <- processx::poll(list(out, err, pro), -1)
    if (pr[[1]] == "ready") {
      if (nchar(x <- processx::processx_conn_read_chars(out))) cat(x)
    }
    if (pr[[2]] == "ready") {
      if (nchar(x <- processx::processx_conn_read_chars(err))) cat(bold(x))
    }
    if (pr[[3]] == "ready") {
      msg <- self$read()
      if (msg$code == 202) break;
    }
  }
}

rs__report_back <- function(self, private, code, text) {
  cmd <- paste0(deparse(rs__status_expr(code, text, fd = 3)), "\n")
  private$write_for_sure(cmd)
}

rs__write_for_sure <- function(self, private, text) {
  while (1) {
    text <- self$write_input(text)
    if (!length(text)) break;
    Sys.sleep(.1)
  }
}

rs__parse_msg <- function(self, private, msg) {
  s <- strsplit(msg, " ", fixed = TRUE)[[1]]
  code <- as.integer(s[1])
  message <- paste(s[-1], collapse = " ")
  if (substr(message, 1, 8) == "base64::") {
    message <- substr(message, 9, nchar(message))
    message <- unserialize(processx::base64_decode(message))
  }

  if (! s[1] %in% names(rs__parse_msg_funcs)) {
    throw(new_error("Unknown message code: `", s[1], "`"))
  }
  structure(
    rs__parse_msg_funcs[[ s[1] ]](self, private, code, message),
    class = "callr_session_result")
}

rs__parse_msg_funcs <- list()
rs__parse_msg_funcs[["200"]] <- function(self, private, code, message) {
  if (private$state != "busy") {
    throw(new_error("Got `done` message when session is not busy"))
  }
  private$state <- "idle"

  res <- private$get_result_and_output()
  c(list(code = code, message = message), res)
}

rs__parse_msg_funcs[["201"]] <- function(self, private, code, message) {
  if (private$state != "starting") {
    throw(new_error("Session already started, invalid `starting` message"))
  }
  private$state <- "idle"
  list(code = code, message = message)
}

rs__parse_msg_funcs[["202"]] <- function(self, private, code, message) {
  private$state <- "idle"
  list(code = code, message = message)
}

rs__parse_msg_funcs[["301"]] <- function(self, private, code, message) {
  ## TODO: progress bar update, what to do here?
  list(code = code, message = message)
}

rs__parse_msg_funcs[["500"]] <- function(self, private, code, message) {
  private$state <- "finished"
  res <- private$get_result_and_output()
  c(list(code = code, message = message), res)
}

rs__parse_msg_funcs[["501"]] <- function(self, private, code, message) {
  private$state <- "finished"
  err <- structure(
    list(message = message),
    class = c("error", "condition"))
  res <- private$get_result_and_output()
  res$error <- err
  c(list(code = code, message = message), res)
}

rs__parse_msg_funcs[["502"]] <- rs__parse_msg_funcs[["501"]]

rs__status_expr <- function(code, text = "", fd = 3L) {
  substitute(
    local({
      pxlib <- as.environment("tools:callr")$`__callr_data__`$pxlib
      code_ <- code; fd_ <- fd; text_ <- text
      data <- paste0(code_, " ", text_, "\n")
      pxlib$write_fd(as.integer(fd), data)
    }),
    list(code = code, fd = fd, text = text)
  )
}

rs__prehook <- function(stdout, stderr) {
  oexpr <- if (!is.null(stdout)) substitute({
    assign(
      ".__stdout__",
      as.environment("tools:callr")$`__callr_data__`$pxlib$
                                   set_stdout_file(`__fn__`),
      envir = as.environment("tools:callr")$`__callr_data__`)
  }, list(`__fn__` = stdout))
  eexpr <- if (!is.null(stderr)) substitute({
    assign(
      ".__stderr__",
      as.environment("tools:callr")$`__callr_data__`$pxlib$
                                   set_stderr_file(`__fn__`),
      envir = as.environment("tools:callr")$`__callr_data__`)
  }, list(`__fn__` = stderr))

  substitute({ o; e }, list(o = oexpr, e = eexpr))
}

rs__posthook <- function(stdout, stderr) {
  oexpr <- if (!is.null(stdout)) substitute({
    as.environment("tools:callr")$`__callr_data__`$
      pxlib$set_stdout(as.environment("tools:callr")$`__callr_data__`$
      .__stdout__)
  })
  eexpr <- if (!is.null(stderr)) substitute({
    as.environment("tools:callr")$`__callr_data__`$
      pxlib$set_stderr(as.environment("tools:callr")$`__callr_data__`$
      .__stderr__)
  })

  substitute({ o; e }, list(o = oexpr, e = eexpr))
}

rs__get_result_and_output <- function(self, private) {

  ## Get stdout and stderr
  stdout <- if (!is.null(private$tmp_output_file) &&
             file.exists(private$tmp_output_file)) {
    tryCatch(suppressWarnings(read_all(private$tmp_output_file)),
             error = function(e) "")
  }
  stderr <- if (!is.null(private$tmp_error_file) &&
             file.exists(private$tmp_error_file)) {
    tryCatch(suppressWarnings(read_all(private$tmp_error_file)),
             error = function(e) "")
  }
  unlink(c(private$tmp_output_file, private$tmp_error_file))
  private$tmp_output_file <- private$tmp_error_file <- NULL

  ## Get result or error from RDS
  outp <- list(
    status = 0,
    stdout = stdout %||% "",
    stderr = stderr %||% "",
    timeout = FALSE
  )
  res <- err <- NULL
  tryCatch(
    res <- get_result(outp, private$options),
    error = function(e) err <<- e,
    interrupt = function(e) err <<- e
  )
  unlink(private$options$tmp_files, recursive = TRUE)
  private$options$tmp_files <- NULL

  ## Assemble result
  list(result = res, stdout = stdout, stderr = stderr, error = err)
}

rs__handle_condition <- function(cond) {

  default_handler <- function(x) {
    classes <- class(x)
    for (cl in classes) {
      opt <- paste0("callr.condition_handler_", cl)
      if (!is.null(val <- getOption(opt)) && is.function(val)) {
        val(x)
        break
      }
    }
  }

  if (is.list(cond) && is.null(cond$muffle)) {
    cond$muffle <- "callr_r_session_muffle"
  }
  withRestarts({
    signalCondition(cond)
    default_handler(cond)
  }, callr_r_session_muffle = function() NULL)

  invisible()
}

## Helper functions ------------------------------------------------------

#' Create options for an [r_session] object
#'
#' @param ... Options to override, named arguments.
#'
#' @export

r_session_options <- function(...) {
  update_options(r_session_options_default(), ...)
}

r_session_options_default <- function() {
  list(
    func = NULL,
    args = NULL,
    libpath = .libPaths(),
    repos = default_repos(),
    stdout = NULL,
    stderr = NULL,
    error = getOption("callr.error", "error"),
    cmdargs = c("--no-readline", "--slave", "--no-save", "--no-restore"),
    system_profile = FALSE,
    user_profile = "project",
    env = c(TERM = "dumb"),
    supervise = FALSE,
    load_hook = NULL,
    extra = list()
  )
}

#' Interactive debugging of persistent R sessions
#'
#' The `r_session$debug()` method is an interactive debugger to inspect
#' the stack of the background process after an error.
#'
#' `$debug()` starts a REPL (Read-Eval-Print-Loop), that evaluates R
#' expressions in the subprocess. It is similar to [browser()] and
#' [debugger()] and also has some extra commands:
#'
#' * `.help` prints a short help message.
#' * `.where` prints the complete stack trace of the error. (The same as
#'   the `$traceback()` method.
#' * `.inspect <n>` switches the "focus" to frame `<n>`. Frame 0 is the
#'   global environment, so `.inspect 0` will switch back to that.
#'
#' To exit the debugger, press the usual interrupt key, i.e. `CTRL+c` or
#' `ESC` in some GUIs.
#'
#' Here is an example session that uses `$debug()` (some output is omitted
#' for brevity):
#'
#' ```
#' # ----------------------------------------------------------------------
#' > rs <- r_session$new()
#' > rs$run(function() knitr::knit("no-such-file"))
#' Error in rs_run(self, private, func, args) :
#'  callr subprocess failed: cannot open the connection
#'
#' > rs$debug()
#' Debugging in process 87361, press CTRL+C (ESC) to quit. Commands:
#'   .where       -- print stack trace
#'   .inspect <n> -- inspect a frame, 0 resets to .GlobalEnv
#'   .help        -- print this message
#'   <cmd>        -- run <cmd> in frame or .GlobalEnv
#'
#' 3: file(con, "r")
#' 2: readLines(input2, encoding = "UTF-8", warn = FALSE)
#' 1: knitr::knit("no-such-file") at #1
#'
#' RS 87361 > .inspect 1
#'
#' RS 87361 (frame 1) > ls()
#'  [1] "encoding"  "envir"     "ext"       "in.file"   "input"     "input.dir"
#'  [7] "input2"    "ocode"     "oconc"     "oenvir"    "oopts"     "optc"
#' [13] "optk"      "otangle"   "out.purl"  "output"    "quiet"     "tangle"
#' [19] "text"
#'
#' RS 87361 (frame 1) > input
#' [1] "no-such-file"
#'
#' RS 87361 (frame 1) > file.exists(input)
#' [1] FALSE
#'
#' RS 87361 (frame 1) > # <CTRL + C>
#' # ----------------------------------------------------------------------
#' ```
#'
#' @name r_session_debug
NULL

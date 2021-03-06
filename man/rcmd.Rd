% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/rcmd.R
\name{rcmd}
\alias{rcmd}
\alias{rcmd_safe}
\title{Run an \verb{R CMD} command}
\usage{
rcmd(
  cmd,
  cmdargs = character(),
  libpath = .libPaths(),
  repos = default_repos(),
  stdout = NULL,
  stderr = NULL,
  poll_connection = TRUE,
  echo = FALSE,
  show = FALSE,
  callback = NULL,
  block_callback = NULL,
  spinner = show && interactive(),
  system_profile = FALSE,
  user_profile = "project",
  env = rcmd_safe_env(),
  timeout = Inf,
  wd = ".",
  fail_on_status = FALSE,
  ...
)

rcmd_safe(
  cmd,
  cmdargs = character(),
  libpath = .libPaths(),
  repos = default_repos(),
  stdout = NULL,
  stderr = NULL,
  poll_connection = TRUE,
  echo = FALSE,
  show = FALSE,
  callback = NULL,
  block_callback = NULL,
  spinner = show && interactive(),
  system_profile = FALSE,
  user_profile = "project",
  env = rcmd_safe_env(),
  timeout = Inf,
  wd = ".",
  fail_on_status = FALSE,
  ...
)
}
\arguments{
\item{cmd}{Command to run. See \code{R --help} from the command
line for the various commands. In the current version of R (3.2.4)
these are: \code{BATCH}, \code{COMPILE}, \code{SHLIB}, \code{INSTALL}, \code{REMOVE}, \code{build},
\code{check}, \code{LINK}, \code{Rprof}, \code{Rdconv}, \code{Rd2pdf}, \code{Rd2txt}, \code{Stangle},
\code{Sweave}, \code{Rdiff}, \code{config}, \code{javareconf}, \code{rtags}.}

\item{cmdargs}{Command line arguments.}

\item{libpath}{The library path.}

\item{repos}{The \code{repos} option. If \code{NULL}, then no
\code{repos} option is set. This options is only used if
\code{user_profile} or \code{system_profile} is set \code{FALSE},
as it is set using the system or the user profile.}

\item{stdout}{Optionally a file name to send the standard output to.}

\item{stderr}{Optionally a file name to send the standard error to.
It may be the same as \code{stdout}, in which case standard error is
redirected to standard output. It can also be the special string
\code{"2>&1"}, in which case standard error will be redirected to standard
output.}

\item{poll_connection}{Whether to have a control connection to
the process. This is used to transmit messages from the subprocess
to the parent.}

\item{echo}{Whether to echo the complete command run by \code{rcmd}.}

\item{show}{Logical, whether to show the standard output on the screen
while the child process is running. Note that this is independent
of the \code{stdout} and \code{stderr} arguments. The standard
error is not shown currently.}

\item{callback}{A function to call for each line of the standard
output and standard error from the child process. It works together
with the \code{show} option; i.e. if \code{show = TRUE}, and a
callback is provided, then the output is shown of the screen, and the
callback is also called.}

\item{block_callback}{A function to call for each block of the standard
output and standard error. This callback is not line oriented, i.e.
multiple lines or half a line can be passed to the callback.}

\item{spinner}{Whether to show a calming spinner on the screen while
the child R session is running. By default it is shown if
\code{show = TRUE} and the R session is interactive.}

\item{system_profile}{Whether to use the system profile file.}

\item{user_profile}{Whether to use the user's profile file.
If this is \code{"project"}, then only the profile from the working
directory is used, but the \code{R_PROFILE_USER} environment variable
and the user level profile are not. See also "Security considerations"
below.}

\item{env}{Environment variables to set for the child process.}

\item{timeout}{Timeout for the function call to finish. It can be a
\link[base:difftime]{base::difftime} object, or a real number, meaning seconds.
If the process does not finish before the timeout period expires,
then a \code{system_command_timeout_error} error is thrown. \code{Inf}
means no timeout.}

\item{wd}{Working directory to use for running the command. Defaults
to the current working directory.}

\item{fail_on_status}{Whether to throw an R error if the command returns
with a non-zero status code. By default no error is thrown.}

\item{...}{Extra arguments are passed to \code{\link[processx:run]{processx::run()}}.}
}
\value{
A list with the command line \verb{$command}),
standard output (\verb{$stdout}), standard error (\code{stderr}),
exit status (\verb{$status}) of the external \verb{R CMD} command, and
whether a timeout was reached (\verb{$timeout}).
}
\description{
Run an \verb{R CMD} command form within R. This will usually start
another R process, from a shell script.
}
\details{
Starting from \code{callr} 2.0.0, \code{rcmd()} has safer defaults, the same as
the \code{rcmd_safe()} default values. Use \code{\link[=rcmd_copycat]{rcmd_copycat()}} for the old
defaults.
}
\section{Security considerations}{


\code{callr} makes a copy of the user's \code{.Renviron} file and potentially of
the local or user \code{.Rprofile}, in the session temporary
directory. Avoid storing sensitive information such as passwords, in
your environment file or your profile, otherwise this information will
get scattered in various files, at least temporarily, until the
subprocess finishes. You can use the keyring package to avoid passwords
in plain files.
}

\examples{
\dontrun{
rcmd("config", "CC")
}
}
\seealso{
Other R CMD commands: 
\code{\link{rcmd_bg}()},
\code{\link{rcmd_copycat}()}
}
\concept{R CMD commands}

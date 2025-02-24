#' Returns information about a `BuildTrigger`.This API is experimental.
#'
#' @family BuildTrigger functions
#' @param projectId ID of the project that owns the trigger
#' @param triggerId ID of the `BuildTrigger` to get or a \code{BuildTriggerResponse} object
#' @importFrom googleAuthR gar_api_generator
#' @export
cr_buildtrigger_get <- function(triggerId,
                                projectId = cr_project_get()) {
  triggerId <- get_buildTriggerResponseId(triggerId)

  url <- sprintf(
    "https://cloudbuild.googleapis.com/v1/projects/%s/triggers/%s",
    projectId, triggerId
  )
  # cloudbuild.projects.triggers.get
  f <- gar_api_generator(url,
                         "GET",
                         data_parse_function = as.buildTriggerResponse
  )

  err_404 <- sprintf("Trigger: %s in project %s not found",
                     triggerId, projectId)

  handle_errs(f, http_404 = cli::cli_alert_danger(err_404))

}

#' Updates a `BuildTrigger` by its project ID and trigger ID.This API is experimental.
#'
#' Seems not to work at the moment (issue #16)
#'
#' @param BuildTrigger The \link{BuildTrigger} object to update to
#' @param projectId ID of the project that owns the trigger
#' @param triggerId ID of the `BuildTrigger` to edit or a previous \code{BuildTriggerResponse} object that will be edited
#' @importFrom googleAuthR gar_api_generator
#' @family BuildTrigger functions
#'
#' @examples
#' \dontrun{
#'
#' github <- GitHubEventsConfig("MarkEdmondson1234/googleCloudRunner",
#'   branch = "master"
#' )
#' bt2 <- cr_buildtrigger("trig2",
#'   trigger = github,
#'   build = "inst/cloudbuild/cloudbuild.yaml"
#' )
#' bt3 <- BuildTrigger(
#'   filename = "inst/cloudbuild/cloudbuild.yaml",
#'   name = "edited1",
#'   tags = "edit",
#'   github = github,
#'   disabled = TRUE,
#'   description = "edited trigger"
#' )
#'
#' edited <- cr_buildtrigger_edit(bt3, triggerId = bt2)
#' }
#'
#' @export
cr_buildtrigger_edit <- function(BuildTrigger,
                                 triggerId,
                                 projectId = cr_project_get()) {
  triggerId <- get_buildTriggerResponseId(triggerId)
  BuildTrigger$id <- triggerId

  url <- sprintf(
    "https://cloudbuild.googleapis.com/v1/projects/%s/triggers/%s",
    projectId, triggerId
  )
  # cloudbuild.projects.triggers.patch
  f <- gar_api_generator(url, "PATCH",
                         data_parse_function = as.buildTriggerResponse,
                         checkTrailingSlash = TRUE
  )
  stopifnot(inherits(BuildTrigger, "BuildTrigger"))

  f(the_body = BuildTrigger)
}

#' Deletes a `BuildTrigger` by its project ID and trigger ID.This API is experimental.
#'
#' @family BuildTrigger functions
#' @param projectId ID of the project that owns the trigger
#' @param triggerId ID of the `BuildTrigger` to get or a \code{BuildTriggerResponse} object
#' @importFrom googleAuthR gar_api_generator
#' @export
cr_buildtrigger_delete <- function(triggerId, projectId = cr_project_get()) {
  triggerId <- get_buildTriggerResponseId(triggerId)

  url <- sprintf(
    "https://cloudbuild.googleapis.com/v1/projects/%s/triggers/%s",
    projectId, triggerId
  )
  # cloudbuild.projects.triggers.delete
  f <- gar_api_generator(url, "DELETE",
                         data_parse_function = function(x) TRUE
  )

  err_404 <- sprintf("BuildTrigger: %s in project %s was not present to delete - returning TRUE",
                     triggerId, projectId)

  handle_errs(f,
              http_404 = cli::cli_alert_info(err_404), return_404 = TRUE,
              return_403 = FALSE,
              projectId = projectId)

}

#' Lists existing `BuildTrigger`s.This API is experimental.
#'
#' @family BuildTrigger functions
#' @param projectId ID of the project for which to list BuildTriggers
#' @param full Return the trigger list with the build information from
#' \code{\link{cr_buildtrigger_get}}
#' @importFrom googleAuthR gar_api_generator
#' @export
#' @seealso \link{cr_build_list} which merges with this list
#' @examples
#' \dontrun{
#'
#' cr_buildtrigger_list()
#' }
cr_buildtrigger_list <- function(projectId = cr_project_get(),
                                 full = FALSE) {
  url <- sprintf(
    "https://cloudbuild.googleapis.com/v1/projects/%s/triggers",
    projectId
  )
  # cloudbuild.projects.triggers.list
  pars <- list(pageToken = "", pageSize = 500)
  f <- gar_api_generator(url, "GET",
                         pars_args = rmNullObs(pars),
                         data_parse_function = parse_buildtrigger_list
  )

  o <- gar_api_page(f,
                    page_f = function(x) x$nextPageToken,
                    page_method = "param",
                    page_arg = "pageToken"
  )

  bts_df <- Reduce(rbind, o)

  parse_files <- function(x) {
    if (is.null(bts_df[[x]])) {
      return(rep(NA, length = nrow(bts_df)))
    }
    unlist(lapply(bts_df[[x]], paste, collapse = ", "))
  }

  df <- data.frame(
    stringsAsFactors = FALSE,
    buildTriggerName = bts_df$name,
    buildTriggerId = bts_df$id,
    buildTriggerCreateTime = bts_df$createTime,
    filename = if (is.null(bts_df$filename)) rep(NA, nrow(bts_df)) else bts_df$filename,
    description = bts_df$description,
    github_name = paste0(bts_df$github$owner, "/", bts_df$github$name),
    ignoredFiles = parse_files("ignoredFiles"),
    includedFiles = parse_files("includedFiles"),
    tags = parse_files("tags"),
    disabled = if (!is.null(bts_df$disabled)) bts_df$disabled else NA
  )
  if (full) {
    if (NROW(df) == 0 || length(df) == 0) return(NULL)
    trigger_data <- lapply(df$buildTriggerId, function(triggerId) {
      x <- cr_buildtrigger_get(triggerId = triggerId,
                               projectId = projectId)
      data.frame(buildTriggerId = triggerId, build = I(list(x)),
                 stringsAsFactors = FALSE)
    })
    trigger_data <- do.call(rbind, trigger_data)
    df <- merge(df, trigger_data, all = TRUE, sort = FALSE)
  }
  df
}


parse_buildtrigger_list <- function(x) {
  o <- x$triggers
  o$build <- NULL # use cr_buildtrigger_get to get build info of a build
  o$substitutions <- NULL
  o$triggerTemplate <- NULL
  o$createTime <- timestamp_to_r(o$createTime)
  o
}

extract_trigger <- function(trigger) {
  trigger_cloudsource <- NULL
  trigger_github <- NULL
  trigger_pubsub <- NULL
  trigger_webhook <- NULL

  if (is.gar_pubsubConfig(trigger)) {
    trigger_pubsub <- trigger
  } else if (is.buildtrigger_repo(trigger) && trigger$type == "github") {
    trigger_github <- trigger$repo
  } else if (is.buildtrigger_repo(trigger) && trigger$type == "cloud_source") {
    trigger_cloudsource <- trigger$repo
  } else if (is.gar_webhookConfig(trigger)) {
    trigger_webhook <- trigger
  } else {
    stop("We should never be here - something wrong with trigger parameter",
         call. = FALSE)
  }
  list(
    trigger_cloudsource = trigger_cloudsource,
    trigger_pubsub = trigger_pubsub,
    trigger_github = trigger_github,
    trigger_webhook = trigger_webhook
  )
}


#' Create a new BuildTrigger
#'
#' @description
#'
#' Build Triggers are a way to have your builds respond to various events, most commonly a git commit or a pubsub event.
#'
#' @inheritParams BuildTrigger
#' @param trigger The trigger source created via \link{cr_buildtrigger_repo} or a pubsub trigger made with \link{cr_buildtrigger_pubsub} or a webhook trigger made with \link{cr_buildtrigger_webhook}
#' @param build The build to trigger created via \link{cr_build_make}, or the file location of the cloudbuild.yaml within the trigger source
#' @param projectId ID of the project for which to configure automatic builds
#' @param trigger_tags Tags for the buildtrigger listing
#' @param overwrite If TRUE will overwrite an existing trigger with the same name
#' @importFrom googleAuthR gar_api_generator
#' @family BuildTrigger functions
#'
#' @details
#'
#' Any source specified in the build will be overwritten to use the trigger as a source (GitHub or Cloud Source Repositories)
#'
#' If you want multiple triggers for a build, then duplicate the build and create another build under a different name but with a different trigger.  Its easier to keep track of.
#'
#' @export
#' @examples
#' cr_project_set("my-project")
#' cr_bucket_set("my-bucket")
#' cloudbuild <- system.file("cloudbuild/cloudbuild.yaml",
#'   package = "googleCloudRunner"
#' )
#' bb <- cr_build_make(cloudbuild)
#'
#' # repo hosted on GitHub
#' gh_trigger <- cr_buildtrigger_repo("MarkEdmondson1234/googleCloudRunner")
#'
#' # repo mirrored to Cloud Source Repositories
#' cs_trigger <- cr_buildtrigger_repo("github_markedmondson1234_googlecloudrunner",
#'   type = "cloud_source"
#' )
#' \dontrun{
#' # build with in-line build code
#' cr_buildtrigger(bb, name = "bt-github-inline", trigger = gh_trigger)
#'
#' # build with in-line build code using Cloud Source Repository
#' cr_buildtrigger(bb, name = "bt-github-inline", trigger = cs_trigger)
#'
#' # build pointing to cloudbuild.yaml within the GitHub repo
#' cr_buildtrigger("inst/cloudbuild/cloudbuild.yaml",
#'   name = "bt-github-file", trigger = gh_trigger
#' )
#'
#' # build with repo mirror from file
#' cr_buildtrigger("inst/cloudbuild/cloudbuild.yaml",
#'   name = "bt-cs-file", trigger = cs_trigger
#' )
#' }
#'
#' # creating build triggers that respond to pubsub events
#' \dontrun{
#' # create a pubsub topic either in webUI or via library(googlePubSubR)
#' library(googlePubsubR)
#' pubsub_auth()
#' topics_create("test-topic")
#' }
#'
#' # create build trigger that will work from pub/subscription
#' pubsub_trigger <- cr_buildtrigger_pubsub("test-topic")
#' pubsub_trigger
#' \dontrun{
#' # create the build trigger with in-line build
#' cr_buildtrigger(bb, name = "pubsub-triggered", trigger = pubsub_trigger)
#' # create scheduler that calls the pub/sub topic
#'
#' cr_schedule("cloud-build-pubsub",
#'   "15 5 * * *",
#'   pubsubTarget = cr_schedule_pubsub("test-topic")
#' )
#' }
#'
#' # create a pubsub trigger that uses github as a source of code to build upon
#' gh <- cr_buildtrigger_repo("MarkEdmondson1234/googleCloudRunner")
#' blist <- cr_build_make(cr_build_yaml(cr_buildstep_r('list.files()')))
#'
#' \dontrun{
#' cr_buildtrigger(blist,
#'                 name = "pubsub-triggered-github-source",
#'                 trigger = pubsub_trigger,
#'                 sourceToBuild = gh)
#' }
#'
cr_buildtrigger <- function(build,
                            name,
                            trigger,
                            description = paste("cr_buildtrigger: ", Sys.time()),
                            disabled = FALSE,
                            substitutions = NULL,
                            ignoredFiles = NULL,
                            includedFiles = NULL,
                            trigger_tags = NULL,
                            projectId = cr_project_get(),
                            sourceToBuild = NULL,
                            overwrite = FALSE) {

  buildTrigger <- cr_buildtrigger_build(
    build = build,
    name = name,
    trigger = trigger,
    description = description,
    disabled = disabled,
    substitutions = substitutions,
    ignoredFiles = ignoredFiles,
    includedFiles = includedFiles,
    trigger_tags = trigger_tags,
    projectId = projectId,
    sourceToBuild = sourceToBuild)

  if (overwrite) {
    suppressMessages(cr_buildtrigger_delete(name, projectId = projectId))
  }

  url <- sprintf(
    "https://cloudbuild.googleapis.com/v1/projects/%s/triggers",
    projectId
  )
  # cloudbuild.projects.triggers.create
  f <- gar_api_generator(url, "POST",
                         data_parse_function = as.buildTriggerResponse,
                         simplifyVector = FALSE
  )
  stopifnot(inherits(buildTrigger, "BuildTrigger"))

  f(the_body = buildTrigger)
}

#' @export
#' @rdname cr_buildtrigger
cr_buildtrigger_build <- function(
  build,
  name,
  trigger,
  description = paste("cr_buildtrigger: ", Sys.time()),
  disabled = FALSE,
  substitutions = NULL,
  ignoredFiles = NULL,
  includedFiles = NULL,
  trigger_tags = NULL,
  projectId = cr_project_get(),
  sourceToBuild = NULL) {

  assertthat::assert_that(
    assertthat::is.string(name),
    is.buildtrigger_repo(trigger) ||
      is.gar_pubsubConfig(trigger) ||
      is.gar_webhookConfig(trigger)
  )

  # build from a file in the repo
  if (is.string(build)) {
    the_build <- NULL
    the_filename <- build
  } else {
    assertthat::assert_that(is.gar_Build(build) || is.Yaml(build))
    the_filename <- NULL

    # remove builds source
    # build$source <- NULL
    # remove repo source, but should keep the bucket if there
    build$source$repoSource <- NULL
    the_build <- build
    # the_build <- cr_build_make(build)
  }

  if (!is.null(sourceToBuild)) {
    assertthat::assert_that(is.buildtrigger_repo(sourceToBuild))
    sourceToBuild <- as.gitRepoSource(sourceToBuild, allow_regex = TRUE)

    if (is.buildtrigger_repo(trigger)) {
      stop("Can't use sourceToBuild for git based triggers", call. = FALSE)
    }
  }

  trigger_ouptut_list <- extract_trigger(trigger)

  # checks on sourceToBuild validity
  if (is.null(sourceToBuild) &&
      (is.gar_webhookConfig(trigger) || is.gar_pubsubConfig(trigger))) {
    cli::cli_alert_warning("No sourceToBuild detected for event based trigger")
  }


  buildTrigger <- BuildTrigger(
    name = name,
    github = trigger_ouptut_list$trigger_github,
    pubsubConfig = trigger_ouptut_list$trigger_pubsub,
    webhookConfig = trigger_ouptut_list$trigger_webhook,
    triggerTemplate = trigger_ouptut_list$trigger_cloudsource,
    build = the_build,
    filename = the_filename,
    description = description,
    tags = trigger_tags,
    disabled = disabled,
    substitutions = substitutions,
    sourceToBuild = sourceToBuild,
    ignoredFiles = ignoredFiles,
    includedFiles = includedFiles
  )
}

as.buildTriggerResponse <- function(x) {
  o <- x
  if (!is.null(o$build)) {
    o$build <- as.gar_Build(x$build)
  }

  if (!is.null(o$pubsubConfig)) {
    o$pubsubConfig <- as.gar_pubsubConfig(o$pubsubConfig)
  }

  structure(
    o,
    class = c("BuildTriggerResponse", "list")
  )
}

is.buildTriggerResponse <- function(x) {
  inherits(x, "BuildTriggerResponse")
}

get_buildTriggerResponseId <- function(x) {
  if (is.buildTriggerResponse(x)) {
    return(x$id)
  } else {
    assertthat::assert_that(assertthat::is.string(x))
  }

  x
}

#' Runs a `BuildTrigger` at a particular source revision.
#'
#' @param RepoSource The \link{RepoSource} object to pass to this method.
#' Set to `NULL` if simply running the trigger
#' @param projectId ID of the project
#' @param triggerId ID of the `BuildTrigger` to get or a \code{BuildTriggerResponse} object
#' @importFrom googleAuthR gar_api_generator
#' @family BuildTrigger functions
#' @export
cr_buildtrigger_run <- function(triggerId,
                                RepoSource,
                                projectId = cr_project_get()) {
  triggerId <- get_buildTriggerResponseId(triggerId)

  url <- sprintf(
    "https://cloudbuild.googleapis.com/v1/projects/%s/triggers/%s:run",
    projectId, triggerId
  )

  # cloudbuild.projects.triggers.run
  f <- gar_api_generator(url, "POST",
                         data_parse_function = as.buildTriggerResponse
  )
  stopifnot(inherits(RepoSource, "gar_RepoSource") || is.null(RepoSource))

  f(the_body = RepoSource)
}

#' Copy a buildtrigger
#'
#' This lets you use the response from \link{cr_buildtrigger_get} for an existing buildtrigger to copy over settings to a new buildtrigger.
#'
#' @param buildTrigger A \code{CloudBuildTriggerResponse} object from \link{cr_buildtrigger_get}
#' @param projectId The projectId you are copying to
#' @inheritParams BuildTrigger
#'
#' @details Overwrite settings for the build trigger you are copying by supplying it as one of the other arguments from \link{BuildTrigger}.
#'
#'
#' @export
#' @family BuildTrigger functions
#' @import assertthat
#' @examples
#' \dontrun{
#' # copying a GitHub buildtrigger across projects and git repos
#' bt <- cr_buildtrigger_get("my-trigger", projectId = "my-project-1")
#'
#' # a new GitHub project
#' gh <- GitHubEventsConfig("username/new-repo",
#'   event = "push",
#'   branch = "^master$"
#' )
#'
#' # give 'Cloud Build Editor' role to your service auth key in new project
#' # then copy configuration across
#' cr_buildtrigger_copy(bt, github = gh, projectId = "my-new-project")
#' }
cr_buildtrigger_copy <- function(buildTrigger,
                                 filename = NULL,
                                 name = NULL,
                                 tags = NULL,
                                 build = NULL,
                                 ignoredFiles = NULL,
                                 github = NULL,
                                 sourceToBuild = NULL,
                                 substitutions = NULL,
                                 includedFiles = NULL,
                                 disabled = NULL,
                                 triggerTemplate = NULL,
                                 projectId = cr_project_get()) {
  assertthat::assert_that(is.buildTriggerResponse(buildTrigger))

  if (!is.null(name)) buildTrigger$name <- name
  if (!is.null(filename)) {
    buildTrigger$filename <- filename
    buildTrigger$build <- NULL
  }
  if (!is.null(build)) {
    buildTrigger$build <- build
    buildTrigger$filename <- NULL
  }
  if (!is.null(tags)) buildTrigger$tags <- tags
  if (!is.null(ignoredFiles)) buildTrigger$ignoredFiles <- ignoredFiles
  if (!is.null(includedFiles)) buildTrigger$includedFiles <- includedFiles
  if (!is.null(substitutions)) buildTrigger$substitutions <- substitutions
  if (!is.null(github)) {
    buildTrigger$github <- github
    buildTrigger$triggerTemplate <- NULL
  }
  if (!is.null(triggerTemplate)) {
    buildTrigger$github <- NULL
    buildTrigger$triggerTemplate <- triggerTemplate
  }
  if (!is.null(disabled)) buildTrigger$disabled <- disabled

  if (!is.null(sourceToBuild)) buildTrigger$sourceToBuild <- sourceToBuild

  buildTrigger <- as.BuildTrigger(buildTrigger)
  url <- sprintf(
    "https://cloudbuild.googleapis.com/v1/projects/%s/triggers",
    projectId
  )
  # cloudbuild.projects.triggers.create
  f <- gar_api_generator(url, "POST",
                         data_parse_function = as.buildTriggerResponse
  )
  stopifnot(inherits(buildTrigger, "BuildTrigger"))

  f(the_body = buildTrigger)
}

library(devtools)
devtools::load_all("/mnt/code/grp_pcml_claims_pcml_claims_prop_water_accuracy_batch/src/models/")
library(pwaimp)
library(dplyr)
library(tryCatchLog)
library(ConfigParser)
library(optparse)

#' Set and get all variables that can be preloaded before running data-pull.
#'
#' @param run_date Airflow run date.
#' @param run_timestamp Airflow run datetime.
#' @return List of variable lists.
get_variables <- function(run_date, run_timestamp){

  # Read config.
  config <- pwaimp::load_config(custom=F, prod = T)

  # Snowflake connection parameters.
  server <- config$get("snf_sds_server",NA,"SNF_CONNECT")
  warehouse <- config$get("snf_sds_warehouse",NA,"SNF_CONNECT")
  role <- config$get("snf_sds_role",NA,"SNF_CONNECT")
  schema <- config$get("input_qry",NA,"SNF_CONNECT")
  auth_key_path <- config$get("priv_key_file_path",NA,"SNF_CONNECT")
  snf_alias <- config$get("snf_alias",NA,"SNF_CONNECT")
  snet_alias <- config$get("snf_key_alias",NA,"SNF_CONNECT")
  query_tag <- config$get("query_tags",NA,"SNF_CONNECT")

  # Snowflake query parameters.
  end_days_ago = config$get("end_days_ago", NA, "DEFAULT")
  start_yr_ago  = config$get("start_yr_ago", NA, "DEFAULT")
  query_path <- config$get("input_qry",NA,"QUERIES")

  # Audit variables.
  model_version <- config$get("model_ver", NA, "AUDIT")
  model_code <- config$get("model_code", NA, "AUDIT")
  model_nm <- config$get("model_name", NA, "AUDIT")
  run_ts <- format(as.POSIXct(run_timestamp), format="%Y-%m-%d %H:%M:%S", tz="UTC")
  batch_ts <- format(Sys.time(), format="%Y-%m-%d %H:%M:%S", tz="UTC")

  # StorageGrid write parameters.
  input_key <- config$get("input_key", NA, "S_G")
  domino_ds <- config$get("domino_ds", NA, "S_G")

  # Return structured lists.
  return(list(
    "snf_client" = list(
      "server" = server,
      "warehouse" = warehouse,
      "role" = role,
      "schema" = schema,
      "auth_key_path" = auth_key_path,
      "snf_alias" = snf_alias,
      "snet_alias" = snet_alias,
      "query_tag" = query_tag
    ),
    "snf_query" = list(
      "end_days_ago" = end_days_ago,
      "start_yr_ago" = start_yr_ago,
      "query_path" = query_path
    ),
    "audit_vars" = list(
      "model_version" = model_version,
      "model_code" = model_code,
      "model_nm" = model_nm,
      "run_ts" = run_ts,
      "batch_ts" = batch_ts,
      "run_dt" = run_date
    ),
    "sg_write" = list(
      "input_key" = input_key,
      "domino_ds" = domino_ds
    )
  ))
}

#' Create a Snowflake object.
#'
#' @param snf_client Named list of Snowflake client variables.
#' @param logger A logger object.
#' @return Snowflake connection object.
get_snf_object <- function(snf_client, logger){
  logger$log_info("Creating Snowflake connection object...")
  snf_obj <- pwaimp::Snowflake_SA_connector$new(
    server = snf_client$server,
    DB = NA,
    WH = snf_client$warehouse,
    ROLE = snf_client$role,
    SCHM=snf_client$schema,
    priv_key_file_path=snf_client$auth_key_path,
    snf_alias=snf_client$snf_alias,
    snet_alias=snf_client$snet_alias,
    query_tags= snf_client$query_tag,
    is_jdbc=T)
  logger$log_info("Snowflake object created.")
  return(snf_obj)
}

#' Add audit variables and write raw data.
#'
#' @param audit_vars Named list of audit variables.
#' @param logger Logger object.
#' @param df Raw data pulled from Snowflake.
#' @return Dataframe with audit fields added.
add_audits_var <- function(audit_vars, logger, df){
  logger$log_info("Adding audit variables to dataframe...")
  df_w_audit <- pwaimp::write_audit_varibles(
    df,
    model_nm = audit_vars$model_nm,
    model_version = audit_vars$model_version,
    model_cd = audit_vars$model_code,
    batch_gmts = audit_vars$batch_ts,
    run_date = audit_vars$run_dt,
    airflow_timestamp = audit_vars$run_ts
  )
  logger$log_info("Audit variables added.")
  return(df_w_audit)
}

#' Write processed data to StorageGrid.
#'
#' @param sg_write Named list of StorageGrid parameters.
#' @param logger Logger object.
#' @param input_df Dataframe with audit fields.
write_input_df <- function(sg_write, logger, input_df){
  logger$log_info("Writing input dataframe to StorageGrid...")
  
  # Ensure correct data types
  input_df <- coerce_input_types(input_df)

  # Convert column names to lowercase
  names(input_df) <- tolower(names(input_df))
  logger$log_info("Input field names converted to lowercase.")

  # Write to StorageGrid
  pwaimp::put.file(input_df, sg_write$input_key, sg_write$domino_ds)
  logger$log_info("Data successfully written to StorageGrid.")
}

#' Execute Data-Pull.
#'
#' @param logger Process logger.
#' @param run_date Airflow run date.
#' @param run_timestamp Airflow run datetime.
main <- function(logger, run_date, run_timestamp){
  logger$log_info("Starting DataPull process...")

  # Collect necessary variables
  vars <- get_variables(run_date, run_timestamp)
  snf_client <- vars$snf_client
  snf_query <- vars$snf_query
  audit_vars <- vars$audit_vars
  sg_write <- vars$sg_write

  # Prepare Snowflake query parameters
  sql_query_params <- list(
    AS_OF_DT = as.Date(run_date),
    END_DAYS_AGO = snf_query$end_days_ago,
    START_YR_AGO = snf_query$start_yr_ago
  )

  # Establish Snowflake connection
  snf_obj <- get_snf_object(snf_client, logger)
  snf_con <- snf_obj$connect()

  # Execute query and store result in `input`
  query <- snf_obj$query_setup_safe(params = sql_query_params, sql_file_path = snf_query$query_path)
  logger$log_message(query)
  input <- snf_obj$select(snf_con, query)

  # Close Snowflake connection
  snf_obj$disconnect()

  # Add audit variables to `input`
  input_w_audit <- add_audits_var(audit_vars, logger, input)

  # Write final dataframe to StorageGrid
  write_input_df(sg_write, logger, input_w_audit)

  logger$log_info("DataPull process completed.")
}

# If script is executed in non-interactive mode (batch job)
if (!interactive()){

  # Expand JVM memory allocation for large result sets
  options(java.parameters = "-Xmx8g")

  # Parse command-line arguments
  option_list = list(
    make_option(c("-d", "--run_date"), type="character", default=toString(Sys.Date()),
                help="Run date", metavar="character"),
    make_option(c("-t", "--run_timestamp"), type="character", default=toString(format(Sys.time(), format="", tz="UTC")),
                help="Run timestamp", metavar="character")
  )

  opt_parser = OptionParser(option_list=option_list)
  opt = parse_args(opt_parser)

  if(is.null(opt$run_date) || is.null(opt$run_timestamp)){
    stop("Missing run date or run timestamp parameter!!")
  }

  # Start execution
  run_date = opt$run_date
  run_timestamp = opt$run_timestamp
  logger <- floggeR$new("Datapull", debug=0)
  main(logger, run_date, run_timestamp)
}

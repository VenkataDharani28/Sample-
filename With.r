#' Write the data-pull data-frame into StorageGrid.
#'
#' @param sg_write Named list of StorageGrid variables.
#' @param logger A logger object.
#' @param input_df The data-pull data-frame.
write_input_df <- function(sg_write, logger, input_df){
  logger$log_info("Writing input data to StorageGrid...")
  
  # Coerce input data types
  input_df <- coerce_input_types(input_df)
  
  # Use 'with()' to provide a context for StorageGrid variables
  with(sg_write, {
    logger$log_info("Converting input field names to lower case...")
    names(input_df) <- tolower(names(input_df))
    
    logger$log_info(glue::glue("Input field names converted to lower case. Writing to StorageGrid..."))
    
    # Perform the StorageGrid write operation within the context
    pwaimp::put.file(input_df, input_key, domino_ds)
  })
  
  logger$log_info("Input written to StorageGrid.")
}


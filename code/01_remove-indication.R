# Timing ------------------------------------------------------------------
tictoc::tic()

# Libraries ---------------------------------------------------------------
library(here)
library(yaml)
library(readr)
library(tibble)
library(dplyr)
library(stringr)
library(purrr)
library(furrr)

# Helpers -----------------------------------------------------------------
process_report = function(path) { report = path |> read_report() |> remove_indication() }

read_report = function(path) {
  
  txt = readLines(path, warn = FALSE)
  
  txt = str_trim(txt)
  txt = manual_edits(txt = txt, path = path)
  
  # Add "." at the end of FINAL REPORT and WET READ headers
  txt = str_replace(txt, "FINAL REPORT", "FINAL REPORT.")
  txt[str_starts(txt, "WET READ")] = paste0(txt[str_starts(txt, "WET READ")], ".")

  return(txt)
}

remove_indication = function(txt) {
  
  # Drop any leading empty lines
  while (txt[1] == "") txt = txt[-1]
  
  # Find indication header
  indication_keys = c(
    "INDICATION",
    "INDICATIONS",
    "INDCATION",
    "CLINICAL INFORMATION",
    "CLINICAL INDICATION",
    "REASON FOR EXAMINATION",
    "REASON FOR EXAM",
    "REASON FOR THE EXAM",
    "HISTORY",
    "CLINICAL HISTORY",
    "PATIENT HISTORY")
  
  is_indication_header = map_lgl(txt, str_starts_any, patterns = indication_keys)
  
  if (all(is_indication_header == FALSE)) {
    out = list(indication = "", 
               body       = paste(txt, collapse = " "))
    return(out)
  }

  indication_start = min(which(is_indication_header))  

  # end is first whitespace after start
  indication_end = min(which((txt == "") & (seq_along(txt) > indication_start)))  
  indication_end = min(indication_end, length(txt))
  indication_lines = seq(indication_start, indication_end)
    
  out = list(indication = paste(txt[indication_lines], collapse = " "), 
             body       = paste(txt[-indication_lines], collapse = " "))
             
  return(out)  
}

str_starts_any = function(string, patterns) {
  starts = sapply(patterns, stringr::str_starts, string = string)
  any(starts)
}

manual_edits = function(txt, path) {
  
  study_id = tools::file_path_sans_ext(basename(path))
  
  switch(study_id,
         s50019718 = str_replace(txt, "improved\\.i ", "improved. "),
         s52674888 = txt |>
           str_remove(" +Low lung$") |>
           str_replace("volumes", "Low lung volumes") |> 
           append("", after = 4),
        s59562049 = append(txt, "", after = 4),
        s54365831 = txt |> 
          str_remove(" +AP single view$") |> 
          str_replace(" ?of the chest", "AP Single view of the chest") |> 
          append("", after = 4),
        txt)
  
}

# Read Files --------------------------------------------------------------
message("Processing reports...")
report_cols = cols_only(study_id = col_integer(),
                        path     = col_character())

report_paths = read_csv(here('raw', 'cxr-study-list.csv.gz'),
                        col_types = report_cols) |> 
  filter(study_id %in% c(58235663, 53071062) == FALSE) |> 
  mutate(path = str_replace(path, 'files', here('raw', 'mimic-cxr-reports')))

plan(multicore, workers = min(30, availableCores() - 2))
reports = report_paths |>   
  mutate(out = future_map(path, process_report)) |> 
  transmute(study_id,
            indication = map_chr(out, "indication"),
            body       = map_chr(out, "body")) |> 
  mutate(indication = str_replace_all(indication, " +", " "),
         body       = str_replace_all(body, " +", " "))

write_csv(reports, here("temp", "mimic_cxr_reports.csv"))


# Done --------------------------------------------------------------------
message("Done.")
tictoc::toc()

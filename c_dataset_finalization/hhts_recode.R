recode_spec <- list(
  
  day = list(  
    
    remap = list(
      end_day = c(`2`=3L, `3`=997L, `4`=2L, `5`=4L, `6`=5L),
      begin_day = c(`2`=3L, `3`=997L, `2`=6L)
  )
  
),

  person = list(

    remap = list(
      student = c(`1`=2L, `4`=1L, `5`=3L, `6`=0L, `7`=4L),
      gender  = c(`1`=2L, `2`=1L),
      office_available = c(`2`=0L),
      commute_freq     = c(`9`=996L)
    ),

    transform = list(

      employment = \(x) {
        x[x %in% 6:7] <- x[x %in% 6:7] - 1L
        x[x == 4L] <- 7L
        x
      },

      school_type = \(x) {
        x[x %in% 12:14]   <- x[x %in% 12:14] - 7L
        x[x %in% 15:17] <- x[x %in% 15:17] - 4L
        x[x == 1L]  <- 2L
        x[x == 5L]  <- 4L
        x[x == 7L]  <- 10L
        x[x == 8L]  <- 997L
        x[x == 11L] <- 1L
        x
      }
    )
  ),

  hh = list(

    remap = list(
      residence_type        = c(`7`=997L),
      prev_res_type   = c(`7`=997L),
      income_detailed = c(`11`=999L)
    ),

    transform = list(

      sample_segment = \(x) {
        x[x > 100L] <- x[x > 100L] - 100L
        x
      },

      prev_home_wa = \(x) {
        x[x %in% 3:4] <- x[x %in% 3:4] - 1L
        x
      },

      prev_rent_own = \(x) {
        x[x == 4L] <- 997L
        x[x == 5L] <- 999L
        x[x == 6L] <- 4L
        x
      },

      participation_group = \(x) x - 2L,

      income_broad = \(x) {
        x[x == 6L] <- 999L
        x[x == 7L] <- 5L
        x[x == 8L] <- 6L
        x
      },

      income_followup = \(x) {
        out <- x
        out[x == 6L] <- 999L
        out[x == 7L] <- 5L
        out[x == 8L] <- 6L
        out
      }
    )
  ),
  
  trip = list(
    
    remap = list(
      o_purpose = c(`97`=99L),
      d_purpose = c(`97`=99L)
    ),
    
    transform = list(
      
      o_purpose_category = \(x) {
        x[x %in% 5:10] <- x[x %in% 5:10] + 1L
        x[x == 14L] <- 5L
        x
      },
      
      d_purpose_category = \(x) {
        x[x %in% 5:10] <- x[x %in% 5:10] + 1L
        x[x == 14L] <- 5L
        x
      }
      ,
      transit_access = \(x) {
        x[x %in% 12:16] <- x[x %in% 12:16] - 5L
        x[x %in% c(1:2,5)] <- x[x %in% 1:2] + 1L
        x[x == 8L] <- 1L
        x[x == 18L] <- 4L
        x[x == 17L] <- 5L
        x[x == 97L] <- 997L
        x
      },
      transit_egress = \(x) {
        x[x %in% 12:16] <- x[x %in% 12:16] - 5L
        x[x %in% c(1:2,5)] <- x[x %in% 1:2] + 1L
        x[x == 8L] <- 1L
        x[x == 18L] <- 4L
        x[x == 17L] <- 5L
        x[x == 97L] <- 997L
        x
      }
    )
  )
)

apply_recodes <- function(dt_list, spec) {
  
  for (nm in intersect(names(spec), names(dt_list))) {
    
    dt <- dt_list[[nm]]
    rules <- spec[[nm]]
    
    ## --- discrete remaps ---
    if (!is.null(rules$remap)) {
      
      cols <- intersect(names(rules$remap), names(dt))
      
      if (length(cols) > 0) {
        dt[, (cols) := Map(
          \(x, map) {
            idx <- match(x, as.integer(names(map)))
            x[!is.na(idx)] <- map[idx[!is.na(idx)]]
            x
          },
          .SD,
          rules$remap[cols]
        ), .SDcols = cols]
      }
    }
    
    ## --- functional transforms ---
    if (!is.null(rules$transform)) {
      
      cols2 <- intersect(names(rules$transform), names(dt))
      
      if (length(cols2) > 0) {
        dt[, (cols2) := Map(
          \(x, f) f(x),
          .SD,
          rules$transform[cols2]
        ), .SDcols = cols2]
      }
    }
    
    dt_list[[nm]] <- dt
  }
  
  invisible(dt_list)
}
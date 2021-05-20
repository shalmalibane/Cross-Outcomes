install.packages("forestplot")
setwd("/Users/shalmali/Desktop/Repro Epi Research/4. Cross-outcomes analysis")
library(forestplot)

# IPCW compared to non weighted estimates for main analysis
#data for adjusted estimates
exp_adj_data <- 
  structure(list(
    mean  = c(NA, NA, 4.35, 2.72, 1.59, NA, 3.02, 2.12, 1.43, NA, 3.60, 1.48, 1.46),
    lower = c(NA, NA, 3.39, 2.58, 1.48, NA, 2.97, 1.93, 1.41, NA, 3.55, 1.35, 1.43),
    upper = c(NA, NA, 5.57, 2.87, 1.70, NA, 3.06, 2.33, 1.46, NA, 3.65, 1.63, 1.49)),
    .Names = c("mean", "lower", "upper"), 
    row.names = c(NA, -13L), 
    class = "data.frame")

#data for IPCW estimates
exp_IPCW_data <- 
  structure(list(
    mean  = c(NA, NA, 4.53, 2.77, 1.57, NA, 3.06, 2.38, 1.49, NA, 3.69, 1.57, 1.46),
    lower = c(NA, NA, 3.32, 2.60, 1.44, NA, 3.01, 2.12, 1.46, NA, 3.64, 1.40, 1.43),
    upper = c(NA, NA, 6.17, 2.95, 1.71, NA, 3.12, 2.67, 1.52, NA, 3.74, 1.76, 1.49)),
    .Names = c("mean", "lower", "upper"), 
    row.names = c(NA, -13L), 
    class = "data.frame")

#data for main analysis estimates
exp_main_data <- 
  structure(list(
    mean  = c(NA, NA, 3.50, 1.98, 1.39, NA, 2.80, 1.97, 1.44, NA, 3.50, 1.56, 1.48),
    lower = c(NA, NA, 2.91, 1.90, 1.31, NA, 2.76, 1.84, 1.42, NA, 3.46, 1.46, 1.46),
    upper = c(NA, NA, 4.21, 2.07, 1.47, NA, 2.83, 2.10, 1.46, NA, 3.54, 1.67, 1.50)),
    .Names = c("mean", "lower", "upper"), 
    row.names = c(NA, -13L), 
    class = "data.frame")

# Table values - to be presented on the left of the forest plot 
tabletext <- cbind(c("Outcome", "Stillbirth at Index Birth","  Stillbirth", 
                     "  Preterm Birth", "  SGA", "Preterm at Index Birth",
                     "  Preterm Birth", "  Stillbirth", "  SGA", "SGA at Index Birth",
                     "  SGA", "  Stillbirth", "  Preterm Birth"), 
                   c("Adjusted RR", "","4.4 (3.4, 5.6)", "2.7 (2.6, 2.9)", 
                     "1.6 (1.5, 1.7)", "", "3.0 (2.9, 3.1)", "2.1 (1.9, 2.3)", 
                     "1.4 (1.4, 1.5)","" ,"3.6 (3.5, 3.7)", "1.5 (1.4, 1.6)", "1.4 (1.4, 1.5)"), 
                   c("IPCW RR", "","4.5 (3.3, 6.2)", "2.8 (2.6, 2.9)", 
                     "1.6 (1.5, 1.7)", "", "3.1 (3.0,  3.1)", "2.4 (2.1, 2.7)",
                     "1.5 (1.4, 1.5)", "", "3.7 (3.6, 3.7)", "1.6 (1.4 1.8)", "1.5 (1.4, 1.5)"),
                   c("Main Analysis Adj. RR", "","3.5 (2.9, 4.2)", "2.0 (1.9, 2.1)", "1.4 (1.3, 1.5)", 
                     "", "2.8 (2.7, 2.8)", "2.0 (1.8, 2.1)", "1.4 (1.4, 1.5)", "",
                     "3.5 (3.4, 3.5)", "1.6 (1.5, 1.7)", "1.5 (1.4, 1.6)"))


# Code for generating forest plot
forestplot(tabletext, 
           txt_gp = fpTxtGp(ticks = gpar(fontfamily = "", cex = 0.5), #specifies font + size for everything on chart
                            xlab  = gpar(fontfamily = "", cex = 0.8),
                            legend = gpar(fontfamily ="", cex = 0.6),
                            summary = gpar(fontfamily ="", cex = 0.8), 
                            label = gpar(fontfamily = "", cex = 0.8)),  
           
           mean = cbind(exp_adj_data$mean, exp_IPCW_data$mean, exp_main_data$mean),  #allows multiple estimates per line
           upper = cbind(exp_adj_data$upper, exp_IPCW_data$upper, exp_main_data$upper),
           lower = cbind(exp_adj_data$lower, exp_IPCW_data$lower, exp_main_data$lower),
           graph.pos = 2,  #where graph is relative to other data
           hrzl_lines = list("2" = gpar(lty = 2)),   #types of x axis lines 
           boxsize = 0.15,  #size of estimate boxes 
           is.summary = c(rep(TRUE,2),rep(FALSE,3), TRUE,rep(FALSE,3),
                          TRUE, rep(FALSE,3)),   # select which lables to bold vs. not (True means bold)
           graphwidth=unit(8,"cm"),  
           zero = 0,
           xlab = "Risk of subsequent adverse outcome",
           grid = structure(c(1, 2, 3, 4, 5, 6),  #create vertical lines on plot at these numbers
                            gp = gpar(lty = 2, col = "#CCCCCF")),
           lineheight=unit(0.8,'cm'),
           col = fpColors(box = c("darkblue", "darkred", "grey"), lines = c("darkblue", "darkred", "grey")),
           vertices = TRUE,
           legend = c("Adj RR", "IPCW", "Main Analysis Adj."),
           legend_args = fpLegend(pos = list("bottomright", "inset"=.01,
                                             "align"="horizontal")))
           

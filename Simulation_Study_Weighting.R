library(MASS)
library(survey)
library(mice)
library(rms)
library(sampling)
library(Hmisc)
library(ggplot2)
library(plyr)

# We define our function for the confidence intervall

CI <- function(x,alpha=0.05){
  n       <- length(x)
  mx      <- mean(x)
  z_alpha <- qnorm(1-alpha/2)   
  s2      <- var(x)
  lb      <- mx - z_alpha*sqrt(s2/n)
  ub      <- mx + z_alpha*sqrt(s2/n)
  return(list(sample_mean=mx, sample_variance=s2, 
              lower_bound=lb, upper_bound=ub))
}
# We create a for loop for one of the 240 simulation runs. 
# It allows us to vary the circumstances (missing data mechanism, nonresponse frequencies etc.)
set.seed(1994)


Missing_data_simulation <- function(N = 100000, n = 1000, mu = c(5, 10, 0), cors = 0.2, 
                                    patterns = c(0, 1, 1),
                                    bycases = TRUE,
                                    weights = NULL, prop = 0.2, 
                                    mech = "MNAR",
                                    type = "RIGHT") {

# Drawing from a multivariate normal distribution to create the synthetic population
# The code allows us to vary the correlation coeeficient, the size of the synthetic population
# and the sample size
data <- as.data.frame(mvrnorm(n = N, mu = mu, 
                                Sigma = matrix(data = 
                                                 c(1, cors, cors, cors,
                                                   1, cors, cors,
                                                   cors, 1), nrow = 3, 
                                                  byrow = T)))

truemean <- mean(data[,1]) # True value of our parameter of interest


# We now use the package "survey" to draw a SR-Sample out of our synthetic population
SI_SAMPLE <- srswor(n, nrow(data))
SRS <- data[SI_SAMPLE>0, ] # Perfect simple random sample without missing data


incomplete <- ampute(SRS, patterns = patterns, 
                            weights = weights,          
                            prop = prop, 
                            mech = mech,
                            bycases = bycases,
                            type = type)$amp  #Generating missing values inside our sample
# So far, for every different correction method (Complete case, mean-imptation etc.)
# a pre defined chunk of code has to be "activated". The function should be redifined
# whenever we want to change the correction method

# Activate for mean imputation
# incomplete <- transform(incomplete, V1 = ifelse(is.na(V1), mean(V1, 
#                        na.rm=TRUE), V1))   # Complete-case Analysis  is na.omit(incomplete)

# Activate for random imputation
#incomplete$V1 <- with(incomplete, impute(V1, 'random'))  

# Activate for stochastic regression imputation
#imp <- mice(incomplete, method = "norm.nob", m = 1, printFlag = FALSE)
#incomplete <- complete(imp)

# Activate for multiple imputation using predictive mean matching
imp <- mice(incomplete, method = "pmm", m = 10, printFlag = FALSE)
incomplete <- complete(imp)


RRMSE <- (mean(incomplete[,1])-truemean)^2/(truemean) # See equation 36
r_bias <- (mean(incomplete[,1])-truemean)/(truemean) # See quation 34

# Defining a if-clause for the coverage rate (equation 35)
CI_ <- CI(incomplete[,1])
lower <- CI_[3]
upper <- CI_[4]
count <- 0
if(lower <= truemean && upper >= truemean){
  count <- 1 #if the population mean is in the CI we count it
  } else {
    count <- 0
}
mylist <- list(RRMSE = RRMSE, TrueMean = truemean, ConfidenceInterval = CI_,
               count = count, RelativeBias = r_bias)
return(mylist) 
}

test <- Missing_data_simulation(N= 100000, n = 1000, cors = 0.9, prop = 0.1, patterns = c(0, 1, 1),
                                     weights = NULL, 
                                mech = "MCAR") # One simulation run to test if the function works

# Here we start the Monte-Carlo Simulation
set.seed(1994)
result <- list() # Results of each simulation run will be stored here
for(i in 1:1000){ # Number of Simulation runs
  resultX <- Missing_data_simulation(N = 100000, # Number of elements in synthetic population
                                     n = 1000,   # Sample size (SRS)
                                     cors = 0.2, # Correlation coefficients
                                    prop = 0.50, # Proportion of missingness 
                                    patterns = c(0, 1, 1), # Missing Data Pattern/Missing Variables only on one variable (Y1)
                                    weights = c(1, 0, 0), # Weights to define the missing data mechanism/Use NULL for MCAR, c(0, 1, 0 for MAR and c(1, 0, 0) for MNAR)
                                    mech = "MNAR",
                                    type = "RIGHT") # Right-Tailed log-shift as standard
  result[[length(result)+1]] <- resultX # Each simulation run is stored in a list
}
result_RRMSE <- unlist(lapply(result, "[", 1)) # Converting into a readable form
counts <- unlist(lapply(result, "[", 4))       # Converting into a readable form
result_r_bias <- unlist(lapply(result, "[", 5))# Converting into a readbale form
sqrt(mean(result_RRMSE)) * 100 # Final Result RRMSE
mean(counts)   * 100           # CI-Coverage Rate
mean(result_r_bias) * 100      # Final Result relative bias

##########################
# Reproduction of used plots in term paper
# Complete simulation results
setwd()
Monte_carlo_simulation <- read.csv("Simulation_results_weighting.csv",
                                   header = TRUE, sep = ",")
# Correcting 

Monte_carlo_simulation$Nonresponse <- as.factor(Monte_carlo_simulation$Nonresponse)
Monte_carlo_simulation$Correlation <- as.factor(Monte_carlo_simulation$Correlation)

Monte_carlo_simulation$RRMSE <- gsub(",", "", Monte_carlo_simulation$RRMSE)
Monte_carlo_simulation$RRMSE <- as.numeric(Monte_carlo_simulation$RRMSE)
Monte_carlo_simulation$RRMSE <- Monte_carlo_simulation$RRMSE / 100

Monte_carlo_simulation$CI.Rate <- gsub(",", "", Monte_carlo_simulation$CI.Rate)
Monte_carlo_simulation$CI.Rate <- as.numeric(Monte_carlo_simulation$CI.Rate)
Monte_carlo_simulation$CI.Rate <- Monte_carlo_simulation$CI.Rate / 100

Monte_carlo_simulation$R.Bias <- gsub(",", "", Monte_carlo_simulation$R.Bias)
Monte_carlo_simulation$R.Bias <- as.numeric(Monte_carlo_simulation$R.Bias)
Monte_carlo_simulation$R.Bias <- Monte_carlo_simulation$R.Bias / 100

str(Monte_carlo_simulation)

# Figure 3: Peformance of Complete case analysis under different correlation in case of MAR

figure_3 <- ggplot(data = Monte_carlo_simulation[which
                                                 (Monte_carlo_simulation$Missing.Data.Mechanism
                                                   == "MAR" & Monte_carlo_simulation$Correction.Method ==
                                                     "Complete Case"),], 
                   aes(x = Nonresponse, y = CI.Rate, 
                   col = Correlation,
                   group = Correlation)) + 
  geom_point() +
  geom_line() +
  geom_hline(yintercept = 95, col = "red") +
  xlab("Non-response-rate") +
  ylab("Coverage Rate (%)") +
  theme_classic()
figure_3

# Figure 4

figure_4 <- ggplot(data = Monte_carlo_simulation[which(Monte_carlo_simulation$Missing.Data.Mechanism
                                                       == "MAR"),], aes(x = Nonresponse, y = CI.Rate, 
                                                      col = Correction.Method, 
                                                      shape = Correlation)) +
  geom_point() +
  geom_hline(yintercept = 95, col = "red") +
  xlab("Non-response-rate") +
  ylab("Relative Bias (%)") +
  theme_classic()

figure_4

# Figure 5

figure_5 <- ggplot(data = Monte_carlo_simulation[which(Monte_carlo_simulation$Missing.Data.Mechanism
                                                       == "MAR"),], aes(x = Nonresponse, y = R.Bias, 
                                                      col = Correction.Method, 
                                                      shape = Correlation)) +
  geom_point() +
  geom_hline(yintercept = 0.0, col = "red") +
  xlab("Non-response-rate") +
  ylab("Relative Bias (%)") +
  theme_classic()

figure_5

# Figure 6: Regression Imputation under MNAR and different correlations

figure_6 <- ggplot(data = Monte_carlo_simulation[which(Monte_carlo_simulation$Correction.Method ==
                                                         "Regression Imputation" & Monte_carlo_simulation$Missing.Data.Mechanism ==
                                                         "MNAR"),], aes(x = Nonresponse, y = R.Bias, 
                                                                        col = Correlation,
                                                                        group = Correlation)) +
  geom_point() +
  geom_line() +
  geom_hline(yintercept = 0.0, col = "red") +
  xlab("Non-response-rate") +
  ylab("Relative Bias (%)") +
  theme_classic()

figure_6

# Figure 7

figure_7 <- ggplot(data = Monte_carlo_simulation[which(Monte_carlo_simulation$Correction.Method ==
                                                         "Multiple Imputation" & Monte_carlo_simulation$Missing.Data.Mechanism ==
                                                         "MAR"),], aes(x = Nonresponse, y = CI.Rate, 
                                                                        col = Correlation,
                                                                        group = Correlation)) +
  geom_point() +
  geom_line() +
  geom_hline(yintercept = 95, col = "red") +
  xlab("Non-response-rate") +
  ylab("Coverage Rate (%)") +
  theme_classic()

figure_7

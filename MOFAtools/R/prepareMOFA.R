
#' @title prepare a MOFA model for training
#' @name prepareMOFA
#' @description Function to prepare a \code{\link{MOFAmodel}} object for training. It requires defining data, model and training options.
#' @param object an untrained \code{\link{MOFAmodel}}
#' @param DirOptions list with Input/Output options, which must contain a 'dataDir' element where temporary text files will be stored 
#' and an 'outFile' with hdf5 extension where the final model will be stored.
#' @param DataOptions list of DataOptions (see \code{\link{getDefaultDataOptions}} details). 
#' If NULL, default data options are used.
#' @param ModelOptions list of ModelOptions (see \code{\link{getDefaultModelOptions}} for details). 
#' If NULL, default model options are used.
#' @param TrainOptions list of TrainOptions (see \code{\link{getDefaultTrainOptions}} for details). 
#' If NULL, default training options are used.
#' @return Returns an untrained \code{\link{MOFAmodel}} with specified data, model and training options
#' @export
#' @examples
#' # Generate a random data set
#' gaussian_data <- matrix(rnorm(100,mean=0,sd=1),10,10)
#' poisson_data <- matrix(rpois(100, lambda=1),10,10)
#' data <- list("gaussian_view"=gaussian_data, "poisson_view"=poisson_data)
#' # Create a MOFA object
#' MOFAobject <- createMOFA(data)
#' # Define I/O options
#' DirOptions <- list("dataDir" = tempdir(), "outFile" = tempfile())
#' # Define Data Options
#' DataOptions <- getDefaultDataOptions()
#' # Define Model Options
#' ModelOptions <- getDefaultModelOptions(MOFAobject)
#' ModelOptions$likelihood <- c("gaussian","poisson")
#' ModelOptions <- getDefaultModelOptions(MOFAobject)
#' # Define Training Options
#' TrainOptions <- getDefaultTrainOptions()
#' TrainOptions$maxiter <- 100
#' # Prepare MOFA object for training
#' MOFAobject <- prepareMOFA(MOFAobject, DirOptions, DataOptions, ModelOptions, TrainOptions)
#' # train a MOFA model
#' MOFAobject <- runMOFA(MOFAobject, DirOptions)
prepareMOFA <- function(object, DirOptions, DataOptions = NULL, ModelOptions = NULL, TrainOptions = NULL) {
  
  # Sanity checks
  if (!is(object, "MOFAmodel")) stop("'object' has to be an instance of MOFAmodel")
  
  # Create temporary folder to store data
  dir.create(DirOptions$dataDir, showWarnings = F)
  
  # Get data options
  message("Checking data options...")
  if (is.null(DataOptions)) {
    message("No data options specified, using default...")
    object@DataOptions <- getDefaultDataOptions()
  } else {
    # (To-do) Check that DataOptions is correct
    object@DataOptions <- DataOptions
  }
  
  # Get training options
  message("Checking training options...")
  if (is.null(TrainOptions)) {
    message("No training options specified, using default...")
    object@TrainOptions <- getDefaultTrainOptions()
  } else {
    # (To-do) Check that TrainOptions is correct
    # if(!class(TrainOptions) == "list" & !all(names(TrainOptions) == names(getDefaultTrainOptions()))) 
    #   stop("'TrainOptions' are misspecified, use the list format provided by getDefaultTrainOptions()")
    object@TrainOptions <- TrainOptions
  }
  
  # Get model options
  message("Checking model options...")
  if(is.null(ModelOptions)) {
    message("No model options specified, using default...")
    object@ModelOptions <- getDefaultModelOptions(object)
  } else {
    # (To-do) Check that ModelOptions is correct
    # if(!class(ModelOptions) == "list" & !all(names(ModelOptions) == names(getDefaultModelOptions(object, silent=T)))) 
      # stop("'TrainOptions' are misspecified, use the list format provided by getDefaultModelOptions()")
    object@ModelOptions <- ModelOptions
  }
  
  # Store views as matrices in .txt files
  message(sprintf("Storing input views in %s...", DirOptions$dataDir))
  for(view in viewNames(object)) {
    write.table(t(object@TrainData[[view]]), file=file.path(DirOptions$dataDir, paste0(view,".txt")),
                sep=object@DataOptions$delimiter, row.names=T, col.names=T, quote=F)
  }
  
  # Store covariates as a .txt file
  if (!is.null(ModelOptions$covariates)) {
    write.table(ModelOptions$covariates, file=file.path(DirOptions$dataDir, "covariates.txt"),
                sep=object@DataOptions$delimiter, row.names=F, col.names=F, quote=F)
  }
  
  # If output already exists, remove it
  if (file.exists(DirOptions$outFile)) {
    file.remove(DirOptions$outFile)
  }
  
  return(object)
}



#' @title Get default training options
#' @name getDefaultTrainOptions
#' @description Function to obtain the default training options.
#' @details The training options are the following: \cr
#' \itemize{
#'  \item{\strong{maxiter}:}{ numeric indicating the maximum number of iterations. 
#'  Default is 1000, but we recommend using the convergence criteria.}
#'  \item{\strong{tolerance}:}{ numeric indicating the convergence threshold based on the change in Evidence Lower Bound (deltaELBO). 
#'  For quick exploration we recommend this to be around 1.0, and for a thorough training we recommend a value of 0.01}
#'  \item{\strong{learnFactors}:}{ logical indicating whether to learn the number of factors. 
#'  The criteria to shut down factors is based on a minimum fraction of variance explained, defined in the DropFactorThreshold option}
#'  \item{\strong{DropFactorThreshold}:}{ numeric indicating the threshold on fraction of variance explained to consider a factor inactive and drop it from the model.
#'  For example, a value of 0.01 implies that factors explaining less than 1\% of variance (in each view) will be dropped.}
#'  \item{\strong{verbose}:}{ logical indicating whether to generate a verbose output.}
#'  \item{\strong{seed}:}{ random seed for reproducibility (default is NULL).}
#' }
#' @return Returns a list with default training options
#' @export
getDefaultTrainOptions <- function() {
  TrainOptions <- list(
    maxiter = 5000,               # Maximum number of iterations
    tolerance = 0.1,              # Convergence threshold based on change in the evidence lower bound
    learnFactors = TRUE,          # (bool) learn the number of factors?
    DropFactorThreshold = 0.02,   # Threshold on fraction of variance explained to drop a factor
    verbose = FALSE,              # verbosity?
    seed = NULL                   # random seed
  )
  return(TrainOptions)
}


#' @title Get default data options
#' @name getDefaultDataOptions
#' @description Function to obtain the default data options.
#' @details The data options are the following: \cr
#' \itemize{
#'  \item{\strong{scaleViews}:}{ logical indicating whether to scale views to have the same unit variance. 
#'  As long as the scale differences between the data sets is not massive, this is not required.
#'  Default is FALSE.}
#'  \item{\strong{centerFeatures}:}{ logical indicating whether to learn the intercept (the means) in a per feature basis.
#'   This prevents you from having to center the data, so this option is always recommended. Default is TRUE.}
#'  \item{\strong{removeIncompleteSamples}:}{ logical indicating whether to remove samples that are not profiled in all omics. 
#'   We recommend this for testing. Default is FALSE.}
#'  \item{\strong{delimiter}:}{ character indicating the delimiter in the input matrices stored as text files. 
#'   The matrices are stored internally by MOFA, so unless you are modifying this, use the default value.}
#' }
#' 
#' @return Returns a list with the default data options.
#' @export
getDefaultDataOptions <- function() {
  DataOptions <- list(
    delimiter = "\t",                # Delimiter for the data
    centerFeatures = FALSE,          # Center features to zero mean (does not apply to binary or count views)
    scaleViews = FALSE,              # Scale views to unit variance (does not apply to binary or count views)
    removeIncompleteSamples = FALSE  # Remove incomplete samples that are not profiled in all omics?
  )
  return(DataOptions)
}

#' @title Get default model options
#' @name getDefaultModelOptions
#' @param object an untrained \code{\link{MOFAmodel}} object
#' @description Function to obtain the default model options.
#' @details The model options are the following: \cr
#' \itemize{
#'  \item{\strong{likelihood}:}{ character vector with data likelihoods per view: 
#'  'gaussian' for continuous data, 'bernoulli' for binary data and 'poisson' for count data.
#'  By default, they are guessed internally.}
#'  \item{\strong{numFactors}:}{ numeric indicating the initial number of factors. 
#'  If you want to learn the number of factors automaticallty and you have no prior expectation, 
#'  we recommend setting this to a large value, around 50. Default is 25.}
#'  \item{\strong{learnIntercept}:}{ logical indicating whether to learn an intercept term to capture differences in feature means.
#'  This prevents you from having to center the data, so this option is always recommended. Default is TRUE.}
#'  \item{\strong{sparsity}:}{ logical indicating whether to use the sparse model. 
#'  This is always recommended, as it will make the loadings more interpretable. Default is TRUE.}
#'  \item{\strong{covariates}:}{ ignore, not implemented yet.}
#' }
#' @return Returns a list with the default model options.
#' @export
getDefaultModelOptions <- function(object) {
  
  # Sanity checks
  if (!is(object, "MOFAmodel")) stop("'object' has to be an instance of MOFAmodel")
  if (!.hasSlot(object,"Dimensions") | length(object@Dimensions) == 0) stop("Dimensions of object need to be defined before getting ModelOptions")
  if (!.hasSlot(object,"InputData")) stop("InputData slot needs to be specified before getting ModelOptions")
  if (!.hasSlot(object,"TrainData")) stop("TrainData slot needs to be specified before getting ModelOptions")
  
  # Guess likelihood type
  # likelihood = rep("gaussian", object@Dimensions[["M"]]); names(likelihood) <- viewNames(object)
  likelihood <- .inferLikelihoods(object)
  message(paste0("Likelihoods guessed automatically: ",paste(likelihood,collapse=" ")))
  
  # Define default model options
  ModelOptions <- list(
    likelihood = likelihood,    # (character vector) likelihood per view [gaussian/bernoulli/poisson]
    learnIntercept = TRUE,      # (bool) include a constant factor of 1s to learn the mean of features (intercept)? If not, you need to center the data
    numFactors = 25,            # (numeric) initial number of latent factors
    sparsity = TRUE,            # use feature-wise sparsity?
    covariates = NULL           # no covariates by default
  )
  
  return(ModelOptions)
}

% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/calculateVarianceExplained.R
\name{calculateVarianceExplained}
\alias{calculateVarianceExplained}
\title{Calculate variance explained by the model}
\usage{
calculateVarianceExplained(object, views = "all", factors = "all",
  include_intercept = TRUE, ...)
}
\arguments{
\item{object}{a \code{\link{MOFAmodel}} object.}

\item{views}{character vector with the view names, or numeric vector with view indexes. Default is 'all'}

\item{factors}{character vector with the factor names, or numeric vector with the factor indexes. Default is 'all'}

\item{include_intercept}{include the intercept factor for calculation of variance explained (only used when an intercept was learned)}
}
\value{
a list with matrices with the amount of variation explained per factor and view, and optionally total variance explained per view and variance explained by each feature alone
}
\description{
Method to calculate variance explained by the MOFA model for each view and latent factor. \cr
As a measure of variance explained for gaussian data we adopt the coefficient of determination (R2). \cr
For non-gaussian views the calculations are based on the normally-distributed pseudo-data 
(for more information on the non-gaussian model see Supplementary Methods of the MOFA paper or Seeger & Bouchard, 2012).
}
\details{
This function takes a trained MOFA model as input and calculates for each view the coefficient of determination (R2),
i.e. the proportion of variance in the data explained by the MOFA factor(s) (both jointly and for each individual factor). 
In case of non-Gaussian data the variance explained on the Gaussian pseudo-data is calculated.
}

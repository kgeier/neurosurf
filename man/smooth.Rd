% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/all_generic.R, R/neighborhood.R
\docType{methods}
\name{smooth}
\alias{smooth}
\alias{smooth,SurfaceGeometry-method}
\alias{smooth,NeuroSurface-method}
\title{smooth a surface}
\usage{
smooth(x, ...)

\S4method{smooth}{SurfaceGeometry}(x, type = c("taubin", "laplace",
  "HClaplace", "fujiLaplace", "angWeight", "surfPreserveLaplace"),
  lambda = 0.7, mu = -0.53, delta = 0.1, iteration = 25)

\S4method{smooth}{NeuroSurface}(x, sigma = 5, ...)
}
\arguments{
\item{x}{the surface object to smooth}

\item{...}{extra args}

\item{type}{the smoothing method}

\item{lambda}{smoothing parameter (see Rvcg::vcgSmooth)}

\item{mu}{smoothing parameter (see Rvcg::vcgSmooth)}

\item{delta}{smoothing parameter (see Rvcg::vcgSmooth)}

\item{iteration}{number of smoothing iterations}

\item{sigma}{the smoothing radius}
}
\description{
smooth a surface
}

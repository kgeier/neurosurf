#' @include all_class.R
#' @include all_generic.R
NULL


.readHeader <- function(file_name) {
  desc <- findSurfaceDescriptor(file_name)
  if (is.null(desc)) {
    stop(paste("could not find reader for file: ", file_name))
  }

  read_meta_info(desc, file_name)
}


#' read a freesurfer annotation file as a \code{LabeledNeuroSurface}
#'
#' @param file_name name of the '.annot' file
#' @param geometry an appropriate \code{SurfaceGeometry} instance
#' @export
read_freesurfer_annot <- function(file_name, geometry) {
  fp <- file(file_name, "rb")
  nvertex <- readBin(fp, integer(),n = 1, size=4, endian="big")
  vertex_dat <- readBin(fp, integer(),n = nvertex*2, size=4, endian="big")
  vertices <- vertex_dat[seq(1,length(vertex_dat), by=2)]
  clabs <- vertex_dat[seq(2,length(vertex_dat), by=2)]
  tags <- readBin(fp, integer(),n=4, size=4, endian="big")
  maxstruc <- tags[3]
  slen <- tags[4]
  fn <- readChar(fp, slen, useBytes=TRUE)
  nlut <- readBin(fp, integer(),n=1, size=4, endian="big")
  labs <- vector(nlut, mode="list")
  for (i in 1:nlut) {
    lnum <- readBin(fp, integer(),n=1, size=4, endian="big")
    len <- readBin(fp, integer(),n=1, size=4, endian="big")
    label <- readChar(fp, len, useBytes=TRUE)
    rgba <- readBin(fp, integer(),n=4, size=4, endian="big")
    #(B * 256^2) + (G * 256) + (R)
    labs[[i]] <- list(
      num=lnum,
      label=label,
      red=rgba[1],
      blue=rgba[2],
      green=rgba[3],
      col=grDevices::rgb(rgba[1]/255, rgba[2]/255, rgba[3]/255),
      code=rgba[3] * 256^2 + (rgba[2] * 256) + rgba[1]
    )
  }

  codes <- match(clabs, sapply(labs, "[[", "code"))
  labels <- sapply(labs, "[[", "label")
  cols <- sapply(labs, "[[", "col")

  close(fp)
  new("LabeledNeuroSurface", geometry=geometry,
      indices=as.integer(vertices+1),
      data=as.numeric(codes),
      labels=as.character(labels),
      cols=as.character(cols))

}

readGIFTIHeader <- function(file_name) {
  hdr <- gifti::readgii(file_name)
  list(header_file=file_name, data_file=file_name,
       info=hdr,
       label=neuroim2::strip_extension(GIFTI_SURFACE_DSET, basename(file_name)))
}

readGIFTIGZHeader <- function(file_name) {
  hdr <- gifti::readgii(file_name)
  list(header_file=file_name, data_file=file_name,
       info=hdr,
       label=neuroim2::strip_extension(GIFTI_GZ_SURFACE_DSET, basename(file_name)))
}


#' readFreesurferAsciiHeader
#'
#' @param file_name the file
readFreesurferAsciiHeader <- function(file_name) {
  has_hemi <- grep(".*\\.[lr]h\\..*", file_name)
  hemi <- if (length(has_hemi) > 0) {
    if (length(grep(".*\\.lh\\..*", file_name))>0) {
      "lh"
    } else if (length(grep(".*\\.rh\\..*", file_name)) > 0) {
      "rh"
    } else {
      "unknown"
    }
  } else {
    "unknown"
  }

  ninfo <- as.integer(strsplit(readLines(file_name, n=2)[2], " ")[[1]])
  list(vertices=ninfo[1], faces=ninfo[2], label=neuroim2::strip_extension(FREESURFER_ASCII_SURFACE_DSET, basename(file_name)),
       embed_dimension=3, header_file=file_name, data_file=file_name, hemi=hemi)
}

#' readFreesurferAsciiGeometry
#'
#' @param file_name the file
#' @importFrom readr read_table
readFreesurferAsciiGeometry <- function(file_name) {
  if (!requireNamespace("rgl", quietly = TRUE)) {
    stop("Pkg needed for this function to work. Please install it.",
         call. = FALSE)
  }
  ninfo <- as.integer(strsplit(readLines(file_name, n=2)[2], " ")[[1]])
  asctab <- read_table(file_name, skip=2)
  #asctab <- readr::read_table(file_name, skip=2, col_names=FALSE)
  vertices <- as.matrix(asctab[1:ninfo[1],1:3])
  nodes <- as.matrix(asctab[(ninfo[1]+1):nrow(asctab),1:3])

  list(vertices=vertices, nodes=nodes, header_file=file_name, data_file=file_name)

}

#' readFreesurferBinaryHeader
#'
#' @param file_name the file
readFreesurferBinaryHeader <- function(file_name) {
  has_hemi <- grep("^[lr]h\\..*", basename(file_name))
  hemi <- if (length(has_hemi) > 0) {
    if (length(grep("^lh.*", basename(file_name))>0)) {
      "lh"
    } else if (length(grep("^rh.*", basename(file_name))>0)) {
      "rh"
    } else {
      "unknown"
    }
  } else {
    "unknown"
  }

  fp <- file(file_name, "rb")
  magic <- readBin(fp, what="raw", n=3)
  created_by <- readLines(fp, 2)
  vcount <- readBin(fp, what="integer", n=1, endian="big")
  fcount <- readBin(fp, what="integer", n=1, endian="big")

  close(fp)

  list(vertices=vcount, faces=fcount, label=basename(file_name),
       embed_dimension=3, header_file=file_name, data_file=file_name, hemi=hemi)
}

#' readFreesurferBinaryGeometry
#'
#' @param file_name the file
#' @importFrom readr read_table
readFreesurferBinaryGeometry <- function(file_name) {
  if (!requireNamespace("rgl", quietly = TRUE)) {
    stop("Pkg needed for this function to work. Please install it.",
         call. = FALSE)
  }

  fp <- file(file_name, "rb")
  magic <- readBin(fp, what="raw", n=3)
  created_by <- readLines(fp, 2)
  vcount <- readBin(fp, what="integer", n=1, endian="big")
  fcount <- readBin(fp, what="integer", n=1, endian="big")

  coords <- readBin(fp, what="double", n=vcount*3, size=4, endian="big")
  coords <- matrix(coords, vcount, 3, byrow=TRUE)

  faces <- readBin(fp, what="integer", n=fcount*3, size=4, endian="big")
  faces <- matrix(faces, fcount, 3, byrow=TRUE)

  close(fp)

  list(coords=coords, faces=faces, header_file=file_name, data_file=file_name)

}



#' readAFNISurfaceHeader
#'
#' @param file_name the name of the AFNI 1D file
#' @importFrom readr read_table
readAFNISurfaceHeader <- function(file_name) {

  #dmat <- readr::read_table(file_name, col_names=FALSE)
  dmat <- read.table(file_name, header=FALSE)

  list(header_file=file_name, data_file=file_name,
       node_count=nrow(dmat), nels=ncol(dmat)-1,
       label=neuroim2::strip_extension(AFNI_SURFACE_DSET, basename(file_name)),
       data=as.matrix(dmat[,2:ncol(dmat)]), nodes=as.vector(dmat[,1]))

}


#' readNIMLSurfaceHeader
#
#' @param file_name the name of the NIML file
readNIMLSurfaceHeader <- function(file_name) {
  p <- neuroim2:::parse_niml_file(file_name)
  whdat <- which(unlist(lapply(p, "[[", "label")) == "SPARSE_DATA")
  dmat <- if (length(whdat) > 1) {
    t(do.call(rbind, lapply(p[[whdat]], "[[", "data")))
  } else {
    t(p[[whdat]]$data)
  }

  whind <- which(unlist(lapply(p, "[[", "label")) == "INDEX_LIST")

  if (length(whind) == 0) {
    warning("readNIMLSurfaceHeader: assuming index is first column of data matrix")
    idat <- dmat[,1]
    dmat <- dmat[, 2:ncol(dmat)]
  } else {
    idat <- p[[whind]]$data[1,]
  }

  list(header_file=file_name, data_file=file_name,
       node_count=nrow(dmat), nels=ncol(dmat),
       label=neuroim2::strip_extension(NIML_SURFACE_DSET, basename(file_name)),
       data=dmat, nodes=idat)
}


#' read_meta_info
#'
#' @param x the file descriptor object
#' @param file_name the name of the file containing meta infromation.
#' @rdname read_meta_info
#' @importMethodsFrom neuroim2 read_meta_info
setMethod(f="read_meta_info",signature=signature(x= "AFNISurfaceFileDescriptor"),
          def=function(x, file_name) {
            .read_meta_info(x, file_name, readAFNISurfaceHeader, AFNISurfaceDataMetaInfo)
          })

#' @rdname read_meta_info
setMethod(f="read_meta_info",signature=signature(x= "NIMLSurfaceFileDescriptor"),
          def=function(x, file_name) {
            .read_meta_info(x, file_name, readNIMLSurfaceHeader, NIMLSurfaceDataMetaInfo)
          })


#' @rdname read_meta_info
setMethod(f="read_meta_info",signature=signature(x= "FreesurferAsciiSurfaceFileDescriptor"),
          def=function(x, file_name) {
            .read_meta_info(x, file_name, readFreesurferAsciiHeader, FreesurferSurfaceGeometryMetaInfo)
          })


#' @rdname read_meta_info
setMethod(f="read_meta_info",signature=signature(x= "FreesurferBinarySurfaceFileDescriptor"),
          def=function(x, file_name) {
            .read_meta_info(x, file_name, readFreesurferBinaryHeader, FreesurferSurfaceGeometryMetaInfo)
          })

#' @rdname read_meta_info
setMethod(f="read_meta_info",signature=signature(x= "GIFTISurfaceFileDescriptor"),
          def=function(x, file_name) {
            .read_meta_info(x, file_name, readGIFTIHeader, GIFTISurfaceDataMetaInfo)
          })


.read_meta_info <- function(desc, file_name, readFunc, constructor) {
  hfile <- neuroim2::header_file(desc, file_name)
  header <- readFunc(hfile)
  header$file_name <- hfile
  constructor(desc, header)
}

#' data_reader
#'
#' construct a reader function
#'
#' @param x object used to create reader from
#'
#' @rdname data_reader
#' @importClassesFrom neuroim2 ColumnReader
setMethod(f="data_reader", signature=signature("SurfaceGeometryMetaInfo"),
          def=function(x) {
            reader <- function(i) {
              if (length(i) == 1 && i == 0) {
                x@node_indices
              } else {
                x@data[,i,drop=FALSE]
              }
            }

            neuroim2::ColumnReader(nrow=as.integer(nrow(x@data)), ncol=as.integer(ncol(x@data)), reader=reader)
          })



#' @rdname data_reader
setMethod(f="data_reader", signature=signature("NIMLSurfaceDataMetaInfo"),
          def=function(x) {
            reader <- function(i) {
              if (length(i) == 1 && i == 0) {
                x@node_indices
              } else {
                x@data[,i,drop=FALSE]
              }
            }

            neuroim2::ColumnReader(nrow=as.integer(nrow(x@data)), ncol=as.integer(ncol(x@data)), reader=reader)
            #new("ColumnReader", nrow=as.integer(nrow(x@data)), ncol=as.integer(ncol(x@data)), reader=reader)
          })




findSurfaceDescriptor <- function(file_name) {
  if (neuroim2::file_matches(NIML_SURFACE_DSET, file_name)) NIML_SURFACE_DSET
  else if (neuroim2::file_matches(FREESURFER_ASCII_SURFACE_DSET, file_name)) FREESURFER_ASCII_SURFACE_DSET
  else if (neuroim2::file_matches(AFNI_SURFACE_DSET, file_name)) AFNI_SURFACE_DSET
  else if (neuroim2::file_matches(GIFTI_SURFACE_DSET, file_name)) GIFTI_SURFACE_DSET
  else if (neuroim2::file_matches(GIFTI_GZ_SURFACE_DSET, file_name)) GIFTI_GZ_SURFACE_DSET
  else FREESURFER_BINARY_SURFACE_DSET
}

GIFTI_SURFACE_DSET <- new("GIFTISurfaceFileDescriptor",
                         file_format="GIFTI",
                         header_encoding="raw",
                         header_extension="gii",
                         data_encoding="gii",
                         data_extension="gii")
GIFTI_GZ_SURFACE_DSET <- new("GIFTISurfaceFileDescriptor",
                          file_format="GIFTI",
                          header_encoding="raw",
                          header_extension="gii.gz",
                          data_encoding="gii.gz",
                          data_extension="gii.gz")


NIML_SURFACE_DSET <- new("NIMLSurfaceFileDescriptor",
                         file_format="NIML",
                         header_encoding="raw",
                         header_extension="niml.dset",
                         data_encoding="raw",
                         data_extension="niml.dset")

AFNI_SURFACE_DSET <- new("AFNISurfaceFileDescriptor",
                         file_format="1D",
                         header_encoding="raw",
                         header_extension="1D.dset",
                         data_encoding="raw",
                         data_extension="1D.dset")

FREESURFER_ASCII_SURFACE_DSET <- new("FreesurferAsciiSurfaceFileDescriptor",
                                     file_format="Freesurfer_ASCII",
                                     header_encoding="text",
                                     header_extension="asc",
                                     data_encoding="raw",
                                     data_extension="asc")

FREESURFER_BINARY_SURFACE_DSET <- new("FreesurferBinarySurfaceFileDescriptor",
                                     file_format="Freesurfer_BINARY",
                                     header_encoding="raw",
                                     header_extension=".",
                                     #header_extension=c("orig", "pial", "inflated", "sphere", "sphere.reg", "white", "smoothwm", "thickness", "volume"),
                                     data_encoding="raw",
                                     data_extension=".")
                                     #data_extension=c("orig", "pial", "inflated", "sphere", "sphere.reg", "white", "smoothwm", "thickness", "volume"))



#' Constructor for \code{\linkS4class{SurfaceGeometryMetaInfo}} class
#' @param descriptor the file descriptor
#' @param header a \code{list} containing header information
FreesurferSurfaceGeometryMetaInfo <- function(descriptor, header) {
  stopifnot(is.numeric(header$vertices))
  stopifnot(is.numeric(header$faces))

  new("FreesurferSurfaceGeometryMetaInfo",
      header_file=header$header_file,
      data_file=header$data_file,
      file_descriptor=descriptor,
      vertices=as.integer(header$vertices),
      faces=as.integer(header$faces),
      label=as.character(header$label),
      hemi=header$hemi,
      embed_dimension=as.integer(header$embed_dimension))
}


#' Constructor for \code{\linkS4class{SurfaceDataMetaInfo}} class
#' @param descriptor the file descriptor
#' @param header a \code{list} containing header information
SurfaceDataMetaInfo <- function(descriptor, header) {
  stopifnot(is.numeric(header$nodes))

  new("SurfaceDataMetaInfo",
      header_file=header$header_file,
      data_file=header$data_file,
      file_descriptor=descriptor,
      node_count=as.integer(header$nodes),
      nels=as.integer(header$nels),
      label=as.character(header$label))
}

#' Constructor for \code{\linkS4class{NIMLSurfaceDataMetaInfo}} class
#' @param descriptor the file descriptor
#' @param header a \code{list} containing header information
#'
NIMLSurfaceDataMetaInfo <- function(descriptor, header) {
  stopifnot(is.numeric(header$nodes))

  new("NIMLSurfaceDataMetaInfo",
      header_file=header$header_file,
      data_file=header$data_file,
      file_descriptor=descriptor,
      node_count=as.integer(header$node_count),
      nels=as.integer(header$nels),
      label=as.character(header$label),
      data=header$data,
      node_indices=as.integer(header$nodes))
}

#' Constructor for \code{AFNISurfaceDataMetaInfo} class
#' @param descriptor the file descriptor
#' @param header a \code{list} containing header information
AFNISurfaceDataMetaInfo <- function(descriptor, header) {
  stopifnot(is.numeric(header$nodes))

  new("NIMLSurfaceDataMetaInfo",
      header_file=header$header_file,
      data_file=header$data_file,
      file_descriptor=descriptor,
      node_count=as.integer(header$node_count),
      nels=as.integer(header$nels),
      label=as.character(header$label),
      data=header$data,
      node_indices=as.integer(header$nodes))
}

#' Constructor for \code{GIFTISurfaceDataMetaInfo} class
#' @param descriptor the file descriptor
#' @param header a \code{list} containing header information
GIFTISurfaceDataMetaInfo <- function(descriptor, header) {
  #stopifnot(is.numeric(header$nodes))
  #browser()
  id0 <- which(header$info$data_info$name == "pointset")
  id1 <- which(header$info$data_info$name == "triangle")
  assertthat::assert_that(length(id0) > 0, msg="gifti surface file must have pointset")
  assertthat::assert_that(length(id1) > 0, msg="gifti surface file must have triangles")
  new("GIFTISurfaceDataMetaInfo",
      header_file=header$header_file,
      data_file=header$data_file,
      file_descriptor=descriptor,
      node_count=as.integer(header$info$data_info$Dim0[id0]),
      nels=1,
      label=as.character(header$label),
      info=header$info)
}


#' @rdname show
setMethod(f="show", signature=signature("SurfaceGeometryMetaInfo"),
          def=function(object) {
            cat("an instance of class",  class(object), "\n\n")
            cat("number of vertices:", "\t", object@vertices, "\n")
            cat("number of faces:", "\t", object@faces, "\n")
            cat("label:", "\t", object@label, "\n")
            cat("hemisphere:", "\t", object@hemi, "\n")
            cat("embed dimension:", "\t", object@embed_dimension, "\n")
          })

#' @rdname show
setMethod(f="show", signature=signature("SurfaceDataMetaInfo"),
          def=function(object) {
            cat("an instance of class",  class(object), "\n\n")
            cat("node_count:", "\t", object@node_count, "\n")
            cat("nels:", "\t", object@nels, "\n")
            cat("label:", "\t", object@label, "\n")
          })


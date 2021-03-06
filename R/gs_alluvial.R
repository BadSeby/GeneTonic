#' Alluvial (sankey) plot for a set of genesets and the associated genes
#'
#' Generate an interactive alluvial plot linking genesets to their associated
#' genes
#'
#' @param res_enrich A `data.frame` object, storing the result of the functional
#' enrichment analysis. See more in the main function, [GeneTonic()], to check the
#' formatting requirements (a minimal set of columns should be present).
#' @param res_de A `DESeqResults` object.
#' @param annotation_obj A `data.frame` object with the feature annotation
#' information, with at least two columns, `gene_id` and `gene_name`.
#' @param gtl A `GeneTonic`-list object, containing in its slots the arguments
#' specified above: `dds`, `res_de`, `res_enrich`, and `annotation_obj` - the names
#' of the list _must_ be specified following the content they are expecting
#' @param n_gs Integer value, corresponding to the maximal number of gene sets to
#' be displayed
#' @param gs_ids Character vector, containing a subset of `gs_id` as they are
#' available in `res_enrich`. Lists the gene sets to be displayed.
#'
#' @return A `plotly` object
#' @export
#'
#' @examples
#'
#' library("macrophage")
#' library("DESeq2")
#' library("org.Hs.eg.db")
#' library("AnnotationDbi")
#'
#' # dds object
#' data("gse", package = "macrophage")
#' dds_macrophage <- DESeqDataSet(gse, design = ~line + condition)
#' rownames(dds_macrophage) <- substr(rownames(dds_macrophage), 1, 15)
#' dds_macrophage <- estimateSizeFactors(dds_macrophage)
#'
#' # annotation object
#' anno_df <- data.frame(
#'   gene_id = rownames(dds_macrophage),
#'   gene_name = mapIds(org.Hs.eg.db,
#'                      keys = rownames(dds_macrophage),
#'                      column = "SYMBOL",
#'                      keytype = "ENSEMBL"),
#'   stringsAsFactors = FALSE,
#'   row.names = rownames(dds_macrophage)
#' )
#'
#' # res object
#' data(res_de_macrophage, package = "GeneTonic")
#' res_de <- res_macrophage_IFNg_vs_naive
#'
#' # res_enrich object
#' data(res_enrich_macrophage, package = "GeneTonic")
#' res_enrich <- shake_topGOtableResult(topgoDE_macrophage_IFNg_vs_naive)
#' res_enrich <- get_aggrscores(res_enrich, res_de, anno_df)
#'
#' gs_alluvial(res_enrich = res_enrich,
#'             res_de = res_de,
#'             annotation_obj = anno_df,
#'             n_gs = 4)
#' # or using the alias...
#' gs_sankey(res_enrich = res_enrich,
#'           res_de = res_de,
#'           annotation_obj = anno_df,
#'           n_gs = 4)
gs_alluvial <- function(res_enrich,
                        res_de,
                        annotation_obj,
                        gtl = NULL,
                        n_gs = 5,
                        gs_ids = NULL) {

  if (!is.null(gtl)) {
    checkup_gtl(gtl)
    dds <- gtl$dds
    res_de <- gtl$res_de
    res_enrich <- gtl$res_enrich
    annotation_obj <- gtl$annotation_obj
  }
  
  # res_enhanced <- get_aggrscores(res_enrich, res_de, annotation_obj = annotation_obj)
  n_gs <- min(n_gs, nrow(res_enrich))

  gs_to_use <- unique(
    c(
      res_enrich$gs_id[seq_len(n_gs)],  # the ones from the top
      gs_ids[gs_ids %in% res_enrich$gs_id]  # the ones specified from the custom list
    )
  )

  enrich2list <- lapply(gs_to_use, function(gs) {
    go_genes <- res_enrich[gs, "gs_genes"]
    go_genes <- unlist(strsplit(go_genes, ","))
    return(go_genes)
  })
  names(enrich2list) <- res_enrich[gs_to_use, "gs_description"]

  list2df <- lapply(seq_along(enrich2list), function(gs) {
    data.frame(
      gsid = rep(names(enrich2list[gs]), length(enrich2list[[gs]])),
      gene = enrich2list[[gs]])
  })
  list2df <- do.call("rbind", list2df)

  list2df$value <- 1
  colnames(list2df) <- c("source", "target", "value")
  list2df$source <- as.character(list2df$source)
  list2df$target <- as.character(list2df$target)
  list2df$target <- paste(list2df$target, " ", sep = "") # genes might need a space for better rendering...

  # From these flows we need to create a node data frame: it lists every entities involved in the flow
  nodes <- data.frame(
    name = c(as.character(list2df$source), as.character(list2df$target)) %>% unique()
  )

  # connections must be provided using id, not using real name like in the links data.frame...
  list2df$id_source <- match(list2df$source, nodes$name) - 1
  list2df$id_target <- match(list2df$target, nodes$name) - 1

  # list2df %>% head

  allnodes <- c(unique(list2df$source), unique(list2df$target))
  allcols <- c(
    viridis(length(unique(list2df$source))),           # for genesets
    rep("steelblue", length(unique(list2df$target)))    # for genes
  )

  p <- plot_ly(
    type = "sankey",
    domain = list(
      x =  c(0,1),
      y =  c(0,1)
    ),
    orientation = "h",
    valueformat = ".0f",
    # valuesuffix = " genes in the set",

    node = list(
      label = allnodes,
      color = allcols,
      pad = 15,
      thickness = 20,
      line = list(color = "black", width = 0.5)
    ),

    link = list(
      source = list2df$id_source,
      target = list2df$id_target,
      value =  list2df$value
    )
  ) %>%
    plotly::layout(
      title = "Geneset-Gene Sankey Diagram", font = list(size = 10)
    )
  return(p)
}

#' @rdname gs_alluvial
#' @export
gs_sankey <- gs_alluvial

clean_addins = function(addins) {
  ## Determine which packages are in CRAN.
  ## Assume others are in github
  addins$is_cran = !grepl("/", addins[,3])

  ## For github packages, get package name
  names = unlist(strsplit(addins$Package[!addins$is_cran], "/"))
  ## Remove github user names
  names = names[seq(2, length(names), by=2)]
  #urls = ifelse(addins$is_cran, "https://cran.r-project.org/package=", "https://github.com")

  ## Nice Package name
  addins$full_name = addins$Package
  addins$Package[!addins$is_cran] = names
  addins
}

read_addins = function(path) {
  read.csv(path, sep="|", header=TRUE, skip=14, stringsAsFactors = FALSE)[-1,]
}


get_addins = function() {
  ## Download raddins.csv from web if possible
  url = "https://raw.githubusercontent.com/csgillespie/addinmanager/master/inst/extdata/raddins.md"
  addins = suppressWarnings(try(read_addins(url), silent=TRUE))

  if(class(addins) == "try-error" || nrow(addins) == 0) {
    message("Can't access online version of addins. Using local copy as fallback.")
    ## Locate file of raddins
    path = system.file("extdata/raddins.md", package = "addinmanager")
    addins = read_addins(path)
  }
  clean_addins(addins)
}


#' Addin manager
#'
#' An RStudio addin for managing addins! When the addin is lauched, you can select
#' which addins to install or remove.
#' @importFrom DT renderDataTable dataTableOutput
#' @import miniUI
#' @importFrom shiny observeEvent stopApp paneViewer runGadget a
#' @importFrom devtools install_github
#' @export
addin_manager = function() {

  # Our ui will be a simple gadget page, which
  # simply displays the time in a 'UI' output.
  ui = miniPage(
    gadgetTitleBar(a(href="https://github.com/csgillespie/addinmanager", "RStudio Addins")),
    miniContentPanel(
      DT::dataTableOutput("addins")
    )
  )

  server = function(input, output, session) {
    ## Set DT page length
    options(DT.options = list(pageLength = 10))

    addins = get_addins()

    ## See which packages are already installed to highlight
    install_pack = installed.packages()[,1]
    highlight = rownames(addins[addins[,3] %in% install_pack,])

    ## Total number of pacakges
    all_packages = as.character(1:nrow(addins))

    output$addins = DT::renderDataTable(addins[,1:3], server = FALSE,
                                        selection = list(mode = 'multiple', selected = highlight),
                                        rownames=FALSE)

    observeEvent(input$done, {
      ## Packages to install
      rows_selected = input$addins_rows_selected
      ## Don't install packages already installed
      select = rows_selected[!(rows_selected %in% highlight)]
      for(i in select) {
        if(addins$is_cran[i])
          install.packages(addins[i,"full_name"])
        else
          devtools::install_github(addins[i,"full_name"])
      }

      ## Packages to remove
      not_select = all_packages[!(all_packages %in% rows_selected)]
      ## Only remove packages already installed
      not_select = not_select[not_select %in% highlight]
      for(i in not_select)
        remove.packages(addins[i,"Package"])

      stopApp()
    })


  }
  viewer = paneViewer(300)
  runGadget(ui, server, viewer = viewer)
}

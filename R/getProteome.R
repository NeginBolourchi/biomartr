#' @title Proteome Retrieval
#' @description Main proteome retrieval function for an organism of interest.
#' By specifying the scientific name of an organism of interest the 
#' corresponding fasta-file storing the proteome of the organism of interest
#' can be downloaded and stored locally. Proteome files can be retrieved from 
#' several databases.
#' @param db a character string specifying the database from which the genome 
#' shall be retrieved:
#' \itemize{
#' \item \code{db = "refseq"}
#' \item \code{db = "genbank"}
#' \item \code{db = "ensembl"}
#' \item \code{db = "uniprot"}
#' }
#' @param organism there are three options to characterize an organism: 
#' \itemize{
#' \item by \code{scientific name}: e.g. \code{organism = "Homo sapiens"}
#' \item by \code{database specific accession identifier}: e.g. \code{organism = "GCF_000001405.37"} (= NCBI RefSeq identifier for \code{Homo sapiens})
#' \item by \code{taxonomic identifier from NCBI Taxonomy}: e.g. \code{organism = "9606"} (= taxid of \code{Homo sapiens})
#' }
#' @param reference a logical value indicating whether or not a genome shall be downloaded if it isn't marked in the database as either a reference genome or a representative genome.
#' @param release the database release version of ENSEMBL (\code{db = "ensembl"}). Default is \code{release = NULL} meaning
#' that the most recent database version is used.
#' @param gunzip a logical value indicating whether or not files should be unzipped.
#' @param path a character string specifying the location (a folder) in which 
#' the corresponding proteome shall be stored. Default is 
#' \code{path} = \code{file.path("_ncbi_downloads","proteomes")}.
#' @author Hajk-Georg Drost
#' @details Internally this function loads the the overview.txt file from NCBI:
#' 
#'  refseq: ftp://ftp.ncbi.nlm.nih.gov/genomes/refseq/
#'  
#'  genbank: ftp://ftp.ncbi.nlm.nih.gov/genomes/genbank/
#' 
#' and creates a directory '_ncbi_downloads/proteomes' to store
#' the proteome of interest as fasta file for future processing.
#' @return File path to downloaded proteome.
#' @examples \dontrun{
#' 
#' # download the proteome of Arabidopsis thaliana from refseq
#' # and store the corresponding proteome file in '_ncbi_downloads/proteomes'
#' file_path <- getProteome( db       = "refseq", 
#'              organism = "Arabidopsis thaliana", 
#'              path     = file.path("_ncbi_downloads","proteomes") )
#' 
#' Ath_proteome <- read_proteome(file_path, format = "fasta")
#' 
#' # download the proteome of Arabidopsis thaliana from genbank
#' # and store the corresponding proteome file in '_ncbi_downloads/proteomes'
#' file_path <- getProteome( db       = "genbank", 
#'              organism = "Arabidopsis thaliana", 
#'              path     = file.path("_ncbi_downloads","proteomes") )
#' 
#' Ath_proteome <- read_proteome(file_path, format = "fasta")
#' }
#' @seealso \code{\link{getGenome}}, \code{\link{getCDS}}, \code{\link{getGFF}},
#' \code{\link{getRNA}}, \code{\link{getRepeatMasker}}, 
#' \code{\link{getAssemblyStats}}, \code{\link{meta.retrieval}}, 
#' \code{\link{read_proteome}}
#' @export

getProteome <-
    function(db = "refseq",
             organism,
             reference = TRUE,
             release = NULL,
             gunzip = FALSE,
             path = file.path("_ncbi_downloads", "proteomes")) {
        if (!is.element(db, c("refseq", "genbank", 
                              "ensembl", "uniprot", "ensemblgenomes")))
            stop(
                "Please select one of the available data bases: 
                'refseq', 'genbank', 'ensembl', 'uniprot', or 'ensemblgenomes'.",
                call. = FALSE
            )
        
        if (db == "ensemblgenomes") {
                organism_name <- is.genome.available(db = db, organism = organism, details = TRUE)$display_name[1]
                
                if (!is.na(organism_name))
                        message("Starting proteome retrieval of '", organism_name, "' from ", db, " ...")
                if (is.na(organism_name))
                        message("Starting proteome retrieval of '", organism, "' from ", db, " ...")
                
                message("\n")
        } else {
            message("Starting proteome retrieval of '", organism, "' from ", db, " ...")
            message("\n")
        }
        
        if (is.element(db, c("refseq", "genbank"))) {
            # get Kingdom Assembly Summary file
            AssemblyFilesAllKingdoms <-
                getKingdomAssemblySummary(db = db)
            
            # test wheter or not genome is available
            if (!suppressMessages(is.genome.available(organism = organism, db = db))){
                    message(
                            "Unfortunately no proteome file could be found for organism '",
                            organism, "'. Thus, the download of this organism has been omitted. Have you tried to specify 'reference = FALSE' ?"
                    )
                    return("Not available")
            }
            if (!file.exists(path)) {
                dir.create(path, recursive = TRUE)
            }
            
            organism_name <- assembly_accession <- taxid <- 
                refseq_category <- version_status <- ftp_path <- NULL
            organism <-
                stringr::str_replace_all(organism, "\\(", "")
            organism <-
                stringr::str_replace_all(organism, "\\)", "")
            
            if (reference) {
                if (!is.taxid(organism)) {
                    FoundOrganism <-
                        dplyr::filter(
                            AssemblyFilesAllKingdoms,
                            stringr::str_detect(organism_name, organism) | 
                                stringr::str_detect(assembly_accession, organism),
                            ((refseq_category == "representative genome") |
                                 (refseq_category == "reference genome")
                            ),
                            (version_status == "latest"), !is.na(ftp_path)
                        ) 
                } else {
                    FoundOrganism <-
                        dplyr::filter(
                            AssemblyFilesAllKingdoms,
                            taxid == as.integer(organism),
                            ((refseq_category == "representative genome") |
                                 (refseq_category == "reference genome")
                            ),
                            (version_status == "latest"), !is.na(ftp_path))
                }
            } else {
                if (!is.taxid(organism)) {
                    FoundOrganism <-
                        dplyr::filter(
                            AssemblyFilesAllKingdoms,
                            stringr::str_detect(organism_name, organism) |
                                stringr::str_detect(assembly_accession, organism),
                            (version_status == "latest"), !is.na(ftp_path)
                        ) 
                } else {
                    FoundOrganism <-
                        dplyr::filter(
                            AssemblyFilesAllKingdoms,
                            taxid == as.integer(organism),
                            (version_status == "latest"), !is.na(ftp_path)
                        ) 
                }
            }
            
            if (nrow(FoundOrganism) == 0) {
                message(
                    paste0(
                        "----------> No reference proteome or representative proteome was found for '",
                        organism, "'. Thus, download for this organism has been omitted.",
                        " Have you tried to specify getProteome(db = '",db,"', organism = '",organism,"' , reference = FALSE) ?",
                        " Alternatively, you can retrieve proteomes using the NCBI accession ID or NCBI Taxonomy ID.",
                        " See '?'is.genome.available' for examples."
                    )
                )
                    return("Not available")
            } else {
                if (nrow(FoundOrganism) > 1) {
                    warnings(
                        "More than one entry has been found for '",
                        organism, "'. Only the first entry '", FoundOrganism[1, 1], "' has been used for subsequent proteome retrieval.",
                        " If you wish to download a different version, please use the NCBI accession ID when specifying the 'organism' argument.",
                        " See ?is.genome.available for examples."
                    )
                    FoundOrganism <- FoundOrganism[1, ]
                }
                
                organism <-
                    stringr::str_replace_all(organism, " ", "_")
                
                download_url <-
                    paste0(FoundOrganism$ftp_path,
                           "/",
                           paste0(
                               basename(FoundOrganism$ftp_path),
                               "_protein.faa.gz"
                           ))
                
                local.org <-
                    stringr::str_replace_all(organism, "-", "_")
                local.org <-
                    stringr::str_replace_all(organism, "\\/", "_")
                
                # if (!exists.ftp.file(url = paste0(FoundOrganism$ftp_path, "/"),
                #                      file.path = download_url)) {
                #     message(
                #         "Unfortunately no proteome file could be found 
                #         for organism '",
                #         organism,
                #         "'. Thus, the download of this organism has 
                #         been omitted."
                #     )
                #     return(FALSE)
                # }
                # 
                if (nrow(FoundOrganism) == 1) {
                    if (file.exists(file.path(
                        path,
                        paste0(local.org, "_protein_", db, ".faa.gz")
                    ))) {
                        message(
                            "File ",
                            file.path(
                                path,
                                paste0(local.org, "_protein_", db, ".faa.gz")
                            ),
                            " exists already. Thus, download has been skipped."
                        )
                    } else {
                        tryCatch({
                            utils::capture.output(
                                custom_download(
                                    download_url,
                                    destfile = file.path(
                                        path,
                                        paste0(local.org, "_protein_", 
                                               db, ".faa.gz")
                                    ),
                                    mode = "wb"
                                )
                            )
                            
                            message("Proteome download of ", organism, " is completed!")
                                
                            # download md5checksum file for organism of interest
                            custom_download(
                            paste0(FoundOrganism$ftp_path,"/md5checksums.txt"),
                                file.path(path, 
                                        paste0(local.org, "_md5checksums.txt")),
                                mode = "wb"
                            )
                            
                            # test check sum
                            md5_file_path <- file.path(path, 
                                                       paste0(local.org, 
                                                        "_md5checksums.txt"))
                            md5_file <-
                                read_md5file(md5_file_path)
                            
                            file_name <- NULL
                            
                            md5_sum <- dplyr::filter(md5_file,
                                            file_name == paste0(" ./", paste0(
                                            basename(FoundOrganism$ftp_path),
                                                "_protein.faa.gz"
                                            )))$md5
                            
                            message("Checking md5 hash of file: ", 
                                    md5_file_path , " ...")
                            
                            if (!(tools::md5sum(file.path(
                                path,
                                paste0(local.org, "_protein_", db, ".faa.gz")
                            )) == md5_sum))
                                stop(
                                    paste0(
                                        "Please download the file '",
                                        md5_file_path,
            "' again. The md5 hash between the downloaded file and the file ",
                                        "stored at NCBI do not match.",
                                        collapse = ""
                                    )
                                )
                            unlink(md5_file_path)
                message("The md5 hash of file '", md5_file_path, "' matches!")
                            
                        }, error = function(e){
                            message(
                                "The download session seems to have timed out at the FTP site '",
                                download_url, "'. This could be due to an overload of queries to the databases.",
                                " Please restart this function to continue the data retrieval process or wait ",
                                "for a while before restarting this function in case your IP address was logged due to an query overload on the server side."
                            )
                            return("Not available")
                        })
                    }
                    
                    docFile(
                        file.name = paste0(local.org, "_protein.faa.gz"),
                        organism  = organism,
                        url       = download_url,
                        database  = db,
                        path      = path,
                        refseq_category = FoundOrganism$refseq_category,
                        assembly_accession = FoundOrganism$assembly_accession,
                        bioproject = FoundOrganism$bioproject,
                        biosample = FoundOrganism$biosample,
                        taxid = FoundOrganism$taxid,
                        infraspecific_name = FoundOrganism$infraspecific_name,
                        version_status = FoundOrganism$version_status,
                        release_type = FoundOrganism$release_type,
                        genome_rep = FoundOrganism$genome_rep,
                        seq_rel_date = FoundOrganism$seq_rel_date,
                        submitter = FoundOrganism$submitter
                    )
                    
                    doc <- tibble::tibble(
                        file_name = paste0(ifelse(is.taxid(organism), paste0("taxid_", local.org), local.org), "_genomic_", db,
                                           ".fna.gz"),
                        organism  = organism,
                        url       = download_url,
                        database  = db,
                        path      = path,
                        refseq_category = FoundOrganism$refseq_category,
                        assembly_accession = FoundOrganism$assembly_accession,
                        bioproject = FoundOrganism$bioproject,
                        biosample = FoundOrganism$biosample,
                        taxid = FoundOrganism$taxid,
                        infraspecific_name = FoundOrganism$infraspecific_name,
                        version_status = FoundOrganism$version_status,
                        release_type = FoundOrganism$release_type,
                        genome_rep = FoundOrganism$genome_rep,
                        seq_rel_date = FoundOrganism$seq_rel_date,
                        submitter = FoundOrganism$submitter
                        
                    )
                    
                    readr::write_tsv(doc, file = file.path(path,paste0("doc_",local.org,"_db_",db,".tsv")))
                    
                    if (!gunzip) {
                            message(
                                    paste0(
                                            "The proteome of '",
                                            organism,
                                            "' has been downloaded to '",
                                            path,
                                            "' and has been named '",
                                            paste0(local.org, "_protein_", db, ".faa.gz"),
                                            "' ."
                                    )
                            )
                            
                    }
                    
                    if (gunzip) {
                            message(
                                    paste0(
                                            "The proteome of '",
                                            organism,
                                            "' has been downloaded to '",
                                            path,
                                            "' and has been named '",
                                            paste0(local.org, "_protein_", db, ".faa"),
                                            "' ."
                                    )
                            )
                            
                    }
                    
                    if (gunzip) {
                            message("Unzipping downloaded file ...")
                            R.utils::gunzip(file.path(path,
                                                      paste0(local.org, "_protein_", db, ".faa.gz")), destname = file.path(path,
                                                                                                                          paste0(local.org, "_protein_", db, ".faa")))
                            return(file.path(path,
                                             paste0(local.org, "_protein_", db, ".faa")))
                    } else {
                            return(file.path(path,
                                             paste0(local.org, "_protein_", db, ".faa.gz")))
                    }
                    
                } else {
                    message(
                        "Something went wrong when trying to download file: ",
                        download_url,
                        " ... Sometimes the internet connection isn't stable and re-running the function might help. Otherwise, could there be an issue with the firewall?"
                    )
                }
            }
        }
        
        if (db == "ensembl") {
            # create result folder
            if (!file.exists(path)) {
                dir.create(path, recursive = TRUE)
            }
            
            # download proteome sequence from ENSEMBL
                proteome.path <-
                        getENSEMBL.Seq(
                                organism,
                                type = "pep",
                                id.type = "all",
                                release = release,
                                path = path
                        )
            
            if (is.logical(proteome.path[1])) {
                if (!proteome.path[1])
                    return(FALSE)
            } else {
                
                taxon_id <- assembly <- name <- accession <- NULL
                
                ensembl_summary <-
                    suppressMessages(is.genome.available(
                        organism = organism,
                        db = "ensembl",
                        details = TRUE
                    ))
                
                if (nrow(ensembl_summary) > 1) {
                    if (is.taxid(organism)) {
                        ensembl_summary <-
                            dplyr::filter(ensembl_summary, taxon_id == as.integer(organism), !is.na(assembly))
                    } else {
                        
                        ensembl_summary <-
                            dplyr::filter(
                                ensembl_summary,
                                (name == stringr::str_to_lower(stringr::str_replace_all(organism, " ", "_"))) |
                                    (accession == organism),
                                    !is.na(assembly)
                            )
                    }
                }
                
                
                new.organism <- ensembl_summary$name[1]
                new.organism <-
                    paste0(
                        stringr::str_to_upper(stringr::str_sub(new.organism, 1, 1)),
                        stringr::str_sub(new.organism, 2, nchar(new.organism))
                    )     
                
                url_api <- paste0(
                    "http://rest.ensembl.org/info/assembly/",
                    new.organism,
                    "?content-type=application/json"
                )
                
                # choose only first entry if not specified otherwise
                if (length(url_api) > 1)
                    url_api <- url_api[1]
                
                if (curl::curl_fetch_memory(url_api)$status_code != 200) {
                    message("The API call '",url_api,"' did not work. This might be due to a non-existing organism that you specified or a corrupted internet or firewall connection.")
                    return("Not available")
                }
                
                # retrieve information from API
                json.qry.info <- jsonlite::fromJSON(url_api)
                
                # generate Proteome documentation
                sink(file.path(
                    path,
                    paste0("doc_", new.organism, "_db_", db, ".txt")
                ))
                
                cat(paste0("File Name: ", proteome.path[1]))
                cat("\n")
                cat(paste0("Download Path: ", proteome.path[2]))
                cat("\n")
                cat(paste0("Organism Name: ", new.organism))
                cat("\n")
                cat(paste0("Database: ", db))
                cat("\n")
                cat(paste0("Download_Date: ", date()))
                cat("\n")
                cat(paste0("assembly_name: ", ifelse(!is.null(json.qry.info$assembly_name), json.qry.info$assembly_name, "none")))
                cat("\n")
                cat(paste0("assembly_date: ", ifelse(!is.null(json.qry.info$assembly_date), json.qry.info$assembly_date, "none")))
                cat("\n")
                cat(
                        paste0(
                                "genebuild_last_geneset_update: ",
                                ifelse(!is.null(json.qry.info$genebuild_last_geneset_update), json.qry.info$genebuild_last_geneset_update, "none")
                        )
                )
                cat("\n")
                cat(paste0(
                        "assembly_accession: ",
                        ifelse(!is.null(json.qry.info$assembly_accession), json.qry.info$assembly_accession, "none")
                ))
                cat("\n")
                cat(
                        paste0(
                                "genebuild_initial_release_date: ",
                                ifelse(!is.null(json.qry.info$genebuild_initial_release_date), json.qry.info$genebuild_initial_release_date, "none")
                        )
                )
                
                sink()
                
                doc <- tibble::tibble(
                        file_name = proteome.path[1],
                        download_path = proteome.path[2],
                        organism = new.organism,
                        database = db,
                        download_data = date(),
                        assembly_name = ifelse(!is.null(json.qry.info$assembly_name), json.qry.info$assembly_name, "none"),
                        assembly_date = ifelse(!is.null(json.qry.info$assembly_date), json.qry.info$assembly_date, "none"),
                        genebuild_last_geneset_update = ifelse(!is.null(json.qry.info$genebuild_last_geneset_update), json.qry.info$genebuild_last_geneset_update, "none"), 
                        assembly_accession = ifelse(!is.null(json.qry.info$assembly_accession), json.qry.info$assembly_accession, "none"),
                        genebuild_initial_release_date = ifelse(!is.null(json.qry.info$genebuild_initial_release_date), json.qry.info$genebuild_initial_release_date, "none")
                        
                )
                
                readr::write_tsv(doc, file = file.path(
                        path,
                        paste0("doc_", new.organism, "_db_", db, ".tsv"))
                )
                
                if (!gunzip) {
                        message(
                                paste0(
                                        "The proteome of '",
                                        ensembl_summary$display_name[1],
                                        "' has been downloaded to '",
                                        path,
                                        "' and has been named '",
                                        basename(proteome.path[1]),
                                        "'."
                                )
                        )
                }
                
                if (gunzip) {
                        message(
                                paste0(
                                        "The proteome of '",
                                        ensembl_summary$display_name[1],
                                        "' has been downloaded to '",
                                        path,
                                        "' and has been named '",
                                        basename(unlist(stringr::str_replace(proteome.path[1], "[.]gz", ""))),
                                        "'."
                                )
                        )
                }
                
                if (gunzip) {
                        message("Unzipping downloaded file ...")
                        R.utils::gunzip(proteome.path[1], destname = unlist(stringr::str_replace(proteome.path[1], "[.]gz", "")))
                        return(unlist(stringr::str_replace(proteome.path[1], "[.]gz", "")))
                } else {
                        return(proteome.path[1])
                }
            }
        }
        
        if (db == "ensemblgenomes") {
            # create result folder
            if (!file.exists(path)) {
                dir.create(path, recursive = TRUE)
            }
            
            # download proteome sequence from ENSEMBLGENOMES
                proteome.path <-
                        getENSEMBLGENOMES.Seq(
                                organism,
                                type = "pep",
                                id.type = "all",
                                release = release,
                                path = path
                        )
            
            if (is.logical(proteome.path[1])) {
                if (!proteome.path[1])
                    return(FALSE)
            } else {
                
                taxon_id <- assembly <- name <- accession <- NULL
                
                ensembl_summary <-
                    suppressMessages(is.genome.available(
                        organism = organism,
                        db = "ensemblgenomes",
                        details = TRUE
                    ))
                
                if (nrow(ensembl_summary) > 1) {
                    if (is.taxid(organism)) {
                        ensembl_summary <-
                            dplyr::filter(ensembl_summary, taxon_id == as.integer(organism), !is.na(assembly))
                    } else {
                        
                        ensembl_summary <-
                            dplyr::filter(
                                ensembl_summary,
                                (name == stringr::str_to_lower(stringr::str_replace_all(organism, " ", "_"))) |
                                    (accession == organism),
                                    !is.na(assembly)
                            )
                    }
                }
                
                new.organism <- ensembl_summary$name[1]
                new.organism <-
                    paste0(
                        stringr::str_to_upper(stringr::str_sub(new.organism, 1, 1)),
                        stringr::str_sub(new.organism, 2, nchar(new.organism))
                    ) 
                
                rest_url <- paste0(
                    "http://rest.ensembl.org/info/assembly/",
                    new.organism,
                    "?content-type=application/json"
                )
                
                if (curl::curl_fetch_memory(rest_url)$status_code != 200) {
                    message(
                        "The url: '",rest_url,"' cannot be reached. This might be due to a connection issue or incorrect url path (e.g. not valid organism name).")
                        return(FALSE)
                }
                
                # test proper API access
              json.qry.info <-
                    jsonlite::fromJSON(rest_url)
              
                # generate Proteome documentation
                sink(file.path(
                        path,
                        paste0("doc_", new.organism, "_db_", db, ".txt")
                ))
                
                cat(paste0("File Name: ", proteome.path[1]))
                cat("\n")
                cat(paste0("Download Path: ", proteome.path[2]))
                cat("\n")
                cat(paste0("Organism Name: ", new.organism))
                cat("\n")
                cat(paste0("Database: ", db))
                cat("\n")
                cat(paste0("Download_Date: ", date()))
                cat("\n")
                cat(paste0("assembly_name: ", ifelse(!is.null(json.qry.info$assembly_name), json.qry.info$assembly_name, "none")))
                cat("\n")
                cat(paste0("assembly_date: ", ifelse(!is.null(json.qry.info$assembly_date), json.qry.info$assembly_date, "none")))
                cat("\n")
                cat(
                        paste0(
                                "genebuild_last_geneset_update: ",
                                ifelse(!is.null(json.qry.info$genebuild_last_geneset_update), json.qry.info$genebuild_last_geneset_update, "none")
                        )
                )
                cat("\n")
                cat(paste0(
                        "assembly_accession: ",
                        ifelse(!is.null(json.qry.info$assembly_accession), json.qry.info$assembly_accession, "none")
                ))
                cat("\n")
                cat(
                        paste0(
                                "genebuild_initial_release_date: ",
                                ifelse(!is.null(json.qry.info$genebuild_initial_release_date), json.qry.info$genebuild_initial_release_date, "none")
                        )
                )
                
                sink()
                
                doc <- tibble::tibble(
                        file_name = proteome.path[1],
                        download_path = proteome.path[2],
                        organism = new.organism,
                        database = db,
                        download_data = date(),
                        assembly_name = ifelse(!is.null(json.qry.info$assembly_name), json.qry.info$assembly_name, "none"),
                        assembly_date = ifelse(!is.null(json.qry.info$assembly_date), json.qry.info$assembly_date, "none"),
                        genebuild_last_geneset_update = ifelse(!is.null(json.qry.info$genebuild_last_geneset_update), json.qry.info$genebuild_last_geneset_update, "none"),
                        assembly_accession = ifelse(!is.null(json.qry.info$assembly_accession), json.qry.info$assembly_accession, "none"), 
                        genebuild_initial_release_date = ifelse(!is.null(json.qry.info$genebuild_initial_release_date), json.qry.info$genebuild_initial_release_date, "none")
                        
                )
                
                readr::write_tsv(doc, file = file.path(
                        path,
                        paste0("doc_", new.organism, "_db_", db, ".tsv"))
                )
                
                if (!gunzip) {
                        message(
                                paste0(
                                        "The proteome of '",
                                        ensembl_summary$display_name,
                                        "' has been downloaded to '",
                                        path,
                                        "' and has been named '",
                                        basename(proteome.path[1]),
                                        "'."
                                )
                        )
                }
                
                if (gunzip) {
                        message(
                                paste0(
                                        "The proteome of '",
                                        ensembl_summary$display_name,
                                        "' has been downloaded to '",
                                        path,
                                        "' and has been named '",
                                        basename(unlist(stringr::str_replace(proteome.path[1], "[.]gz", ""))),
                                        "'."
                                )
                        )
                }
                
                if (gunzip) {
                        message("Unzipping downloaded file ...")
                        R.utils::gunzip(proteome.path[1], destname = unlist(stringr::str_replace(proteome.path[1], "[.]gz", "")))
                        return(unlist(stringr::str_replace(proteome.path[1], "[.]gz", "")))
                } else {
                        return(proteome.path[1])
                }
            }
        }
        
        if (db == "uniprot") {
                
                if (!file.exists(path)) {
                        dir.create(path, recursive = TRUE)
                }
                
                getUniProtSeq(organism = organism, path = path, update = TRUE, gunzip = gunzip)
                
        }
    }







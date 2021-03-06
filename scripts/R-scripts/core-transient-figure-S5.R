# Code for running core-transient analysis
# and data summaries over all formatted datasets.
#
# Input files are named propOcc_XXX.csv where
# XXX is the dataset ID.


library(lme4)
library(plyr) # for core-transient functions
library(ggplot2)
library(tidyr)
library(maps)
library(gridExtra)
library(RColorBrewer)
library(sp)
library(rgdal)
library(raster)
library(dplyr)
library(digest)
library(sads)
library(purrr)
library(ggplot2)
library(cowplot)

source('scripts/R-scripts/core-transient_functions.R')

# Specify here the datasetIDs and then run the code below.
dataformattingtable = read.csv('data_formatting_table.csv', header = T) 

datasetIDs = dataformattingtable$dataset_ID[dataformattingtable$format_flag == 1]

# BBS (dataset 1) will be analyzed separately for now.
datasetIDs = datasetIDs[!datasetIDs %in% c(1)]

##### prep for all figures 25#####
# Read in datasets
taxcolors = read.csv("output/tabular_data/taxcolors.csv", header = TRUE)
occ_taxa = read.csv("output/tabular_data/occ_taxa_25.csv", header = TRUE)
areamerge = read.csv("output/tabular_data/areamerge.csv", header = TRUE)
allrich = read.csv("output/tabular_data/allrich.csv", header = TRUE)
notransrich = read.csv("output/tabular_data/notransrich_25.csv", header = TRUE)
bbs_abun_occ = read.csv("data/BBS/bbs_abun_occ.csv", header = TRUE)
bbs_occ = read.csv("data/BBS/bbs_abun4_spRich.csv", header = TRUE)
summ25 = read.csv('output/tabular_data/core-transient_summary_25.csv', header=T)


bbs_count = read.csv("data/BBS/bbs_2000_2014.csv", header = TRUE)
bbs_occ_aou = read.csv("data/BBS/bbs_occ_2000_2014.csv", header = TRUE)

# addings symbols to taxcolors
symbols = c(15, 16, 15, 17, 16, 15, 16) 
Type = c("Invertebrate", "Vertebrate", "Invertebrate", "Plant", "Vertebrate", "Invertebrate", "Vertebrate") 
taxcolors = cbind(taxcolors, Type,symbols)

# calc bbs with and without trans
notransbbs = bbs_abun_occ %>% filter(occupancy > 1/4) %>% dplyr::count(stateroute, scale) %>% filter(scale == 50)
names(notransbbs) = c("stateroute", "scale", "spRichnotrans")

allbbs = bbs_abun_occ %>% dplyr::count(stateroute, scale) %>% filter(scale == 50)
names(allbbs) = c("stateroute", "scale", "spRich")

# create bbs files
bbs_count4a = dplyr::rename(bbs_count, year = Year, site = stateroute, species = aou, count = speciestotal)
bbs_count4a$datasetID = 1

# bbs_abun_occ1 = subset(bbs_abun_occ, scale ==  50)
bbs_occ_aou = dplyr::rename(bbs_occ_aou, site = stateroute, species = aou, propOcc = occ)
bbs_occ_aou$datasetID  = 1
bbs_occ4a = bbs_occ_aou[, c("datasetID", "site", "species", "propOcc")]


# addings symbols to taxcolors
symbols = c(15, 16, 15, 17, 16, 15, 16) 
Type = c("Invertebrate", "Vertebrate", "Invertebrate", "Plant", "Vertebrate", "Invertebrate", "Vertebrate") 
taxcolors = cbind(taxcolors, Type,symbols)

# calc bbs with and without trans
notransbbs = bbs_abun_occ %>% filter(occupancy > 1/4) %>% dplyr::count(stateroute, scale) %>% filter(scale == 50)
names(notransbbs) = c("stateroute", "scale", "spRichnotrans")

allbbs = bbs_abun_occ %>% dplyr::count(stateroute, scale) %>% filter(scale == 50)
names(allbbs) = c("stateroute", "scale", "spRich")

# Figure 4a in sep script
#' Get list of dataset IDS for datasets that meet criteria for analysis including:
#' * Study wide criteria
#' * Has raw abundance data (not cover or density)
get_valid_datasetIDs = function(){
  dataformattingtable = read.csv('data_formatting_table.csv')
  datasetIDs = dataformattingtable %>%
    filter(format_flag == 1, countFormat %in% c('count', 'abundance')) %>% 
    # Remove count datasets with decimal values
    filter(!dataset_ID %in% c(226, 228, 247, 264, 298, 299, 300, 301)) %>%
    # exclude BBS for now and analyze it separately
    filter(dataset_ID !=1) %>% 
    dplyr::select(dataset_ID)
}

#' Get table of species abundances
#' 
get_abund_data  = function(datasetIDs){
  datasetIDs = datasetIDs$dataset_ID
  dataset_path = 'data/standardized_datasets/'
  abund_data = data.frame()
  for (dataset in datasetIDs){
    filename = paste('dataset_', dataset, '.csv', sep = '')
    print(paste("Loading:", filename))
    site_data = read.csv(file.path(dataset_path, filename), stringsAsFactors = FALSE, fileEncoding = 'latin1')
    abund_data = rbind(abund_data, site_data)
  }
  # Strip zeros which are included to document a sampling event occurred
  abund_data = abund_data[abund_data$count != 0,]
  return(abund_data)
}

#' Get table of species proportional occupancies
#' 
get_propocc_data  = function(datasetIDs){
  datasetIDs = datasetIDs$dataset_ID
  dataset_path = 'data/propOcc_datasets/'
  propocc_data = data.frame()
  for (dataset in datasetIDs){
    filename = paste('propOcc_', dataset, '.csv', sep = '')
    print(paste("Loading:", filename))
    site_data = read.csv(file.path(dataset_path, filename), stringsAsFactors = FALSE, fileEncoding = 'latin1')
    propocc_data = rbind(propocc_data, site_data)
  }
  return(propocc_data)
}


#' Sum the abundances for each species-site combination across years
sum_abunds = function(abund_data){
  summed_abunds = abund_data %>%
    group_by(datasetID, site, species) %>%
    dplyr::summarize(abunds = sum(count)) %>%
    filter(abunds != 0)
  return(summed_abunds)
}

sad_examp = c(109, 14, 4, 4, 680, 195, 13, 3, 123, 116, 1, 5, 105, 26, 14, 2, 9, 29, 15, 133, 5, 41, 45, 33, 
              17, 27, 37, 11, 169, 1, 27, 7, 19, 23, 100, 4, 8, 5, 19, 1, 21, 12, 6, 1, 10, 2, 1, 94, 2, 4, 28, 1, 3, 
              34, 3, 20, 72, 21, 1, 84, 10, 528, 18, 1, 1, 10, 10, 48, 7)

#' Get the AICc weight for the log-series compared to the Poisson log-normal
#' abundance distribution
#' 
#' @param abunds vector of abundances
#' 
#' @return vector of weights for the log-series
#' 
#' @examples 
#' get_sad_weights(c(10, 20, 5, 1, 1, 2, 3, 7))
get_logseries_weight = function(abunds){
  stopifnot(all(abunds == floor(abunds))) # Check that all values are counts
  abunds = abunds[abunds != 0] # SADs are fit only on species that are present
  tryCatch({
    fits = c(fitsad(abunds, 'ls'), fitsad(abunds, 'poilog'))
    aics = sapply(fits, AICc)
    min_aic = min(aics)
    deltas = aics - min_aic
    rellike = exp(-0.5 * deltas)
    weights = rellike / sum(rellike)
    logseries_weight = weights[1]
    return(logseries_weight)
  }, error = function(e) {
    logseries_weight = NA
    return(logseries_weight)
  }
  )
}

datasetIDs = get_valid_datasetIDs()
abund_data = get_abund_data(datasetIDs)
propocc_data = get_propocc_data(datasetIDs)
summed_abunds = sum_abunds(abund_data)
sad_data = left_join(summed_abunds, propocc_data, by = c('datasetID', 'site', 'species'))

logseries_weights_incl = sad_data %>%
  group_by(datasetID, site) %>% 
  dplyr::summarize(weights = get_logseries_weight(abunds), treatment = 'All\nspecies')

logseries_weights_excl = sad_data %>%
  filter(propOcc > 1/4) %>%
  group_by(datasetID, site) %>% 
  dplyr::summarize(weights = get_logseries_weight(abunds), treatment = 'Excluding\ntransients')

logseries_weights = rbind(logseries_weights_incl, logseries_weights_excl)
# write.csv(logseries_weights, "output/tabular_data/logseries_weights.csv")
# logseries_weights = read.csv("output/tabular_data/logseries_weights.csv", header = TRUE)


colscale = c("dark orange2","yellow")
k = ggplot(logseries_weights,aes(x=weights,fill=treatment))+geom_histogram(bins = 20, position = "identity", alpha = 0.7)+ xlab("Transient Status") + ylab("Proportion of Species") + scale_y_continuous(breaks=c(0,150,275)) + scale_fill_manual(labels = c("All species","All species excluding transients"),values = colscale)+ theme_classic() + theme(axis.text.x=element_blank(), axis.ticks.x=element_blank(),axis.text.y=element_text(size=30, color = "black"),axis.title.y=element_text(size=40,angle=90,vjust = 5),axis.title.x=element_text(size=40, vjust = -7))  + ylab("Frequency") + xlab("Akaike Weight") + theme(legend.position = "none") +theme(plot.margin=unit(c(0.35,1,2,1.7),"cm")) 
k

#### Figure 4b ####
# read in route level ndvi and elevation data (radius = 40 km)
# we want to agg by month here
gimms_ndvi = read.csv("output/tabular_data/gimms_ndvi_bbs_data.csv", header = TRUE)
gimms_agg = gimms_ndvi %>% filter(month == c("may", "jun", "jul")) %>% 
  group_by(site_id)  %>%  dplyr::summarise(ndvi=mean(ndvi))

lat_scale_rich = read.csv("output/tabular_data/lat_scale_rich_25.csv", header = TRUE)
lat_scale_bbs = filter(lat_scale_rich, datasetID == 1)
lat_scale_bbs$site_id = sapply(strsplit(as.character(lat_scale_bbs$site), split='-', fixed=TRUE), function(x) (x[1]))
lat_scale_bbs$site_id = as.integer(lat_scale_bbs$site_id)

lat_scale_test = filter(lat_scale_bbs, datasetID == 1) %>% separate(., site, c("stateroute", "level", "number"), sep = "-") %>% filter(., level == 50)
lat_scale_test$site = lat_scale_test$stateroute

bbsocc = read.csv('data/propOcc_datasets/propOcc_1.csv', header=T, stringsAsFactors = F)
rich = dplyr::count(bbsocc, site)
rich_notrans = bbsocc %>% filter(propOcc > 1/4) %>% count(site)

bbsocc_rich = left_join(bbsocc, rich)
bbsocc_rich$spRich = bbsocc_rich$n
bbsocc_rich = bbsocc_rich[ , !names(bbsocc_rich) %in% c("n")] 
bbsocc_rich = left_join(bbsocc_rich, rich_notrans)
bbsocc_rich$spRichnotrans = bbsocc_rich$n
bbsocc_rich = bbsocc_rich[ , !names(bbsocc_rich) %in% c("n")] 

bbs_env = left_join(bbsocc_rich, gimms_agg, c("site" = "site_id"))
bbs_env = merge(bbs_env, lat_scale_test[,c("stateroute", "elev.point", "elev.mean", "elev.var")], by.x = "site", by.y = "stateroute")

# cor test not really working - need for loop?
cor.test(bbs_env$spRich, bbs_env$ndvi)
bar1 = cor.test(bbs_env$spRich, bbs_env$ndvi)$estimate
CI1lower =  cor.test(bbs_env$spRich, bbs_env$ndvi)$conf.int[1]
CI1upper = cor.test(bbs_env$spRich, bbs_env$ndvi)$conf.int[2]
bar3 = cor.test(bbs_env$spRich, bbs_env$elev.mean)$estimate
CI3lower = cor.test(bbs_env$spRich, bbs_env$elev.mean)$conf.int[1]
CI3upper =  cor.test(bbs_env$spRich, bbs_env$elev.mean)$conf.int[2]

bar2 = cor.test(bbs_env$spRichnotrans, bbs_env$ndvi)$estimate
CI2lower = cor.test(bbs_env$spRichnotrans, bbs_env$ndvi)$conf.int[1]
CI2upper =   cor.test(bbs_env$spRichnotrans, bbs_env$ndvi)$conf.int[2]
bar4 = cor.test(bbs_env$spRichnotrans, bbs_env$elev.mean)$estimate
CI4lower =  cor.test(bbs_env$spRichnotrans, bbs_env$elev.mean)$conf.int[1]
CI4upper =  cor.test(bbs_env$spRichnotrans, bbs_env$elev.mean)$conf.int[2]

bar5 = cor.test(bbs_env$spRich-bbs_env$spRichnotrans, bbs_env$ndvi)$estimate
CI5lower = cor.test(bbs_env$spRich-bbs_env$spRichnotrans, bbs_env$ndvi)$conf.int[1]
CI5upper =  cor.test(bbs_env$spRich-bbs_env$spRichnotrans, bbs_env$ndvi)$conf.int[2]
bar6 = cor.test(bbs_env$spRich-bbs_env$spRichnotrans, bbs_env$elev.mean)$estimate
CI6lower = cor.test(bbs_env$spRich-bbs_env$spRichnotrans, bbs_env$elev.mean)$conf.int[1]
CI6upper =  cor.test(bbs_env$spRich-bbs_env$spRichnotrans, bbs_env$elev.mean)$conf.int[2]

corr_res <- data.frame(All = c(bar1, bar3), Ntrans = c(bar2, bar4), Trans = c(bar5, bar6)) 
corr_res$env = c("NDVI", "Elevation")
corr_res_long = gather(corr_res, "class","value", c(All:Trans))
corr_res_long$CIlower = c(CI1lower,CI3lower,CI2lower,CI4lower, CI5lower, CI6lower)
corr_res_long$CIupper = c(CI1upper,CI3upper,CI2upper,CI4upper, CI5upper, CI6upper)
corr_res_long$env = factor(corr_res_long$env, levels = c("NDVI", "Elevation"), ordered = TRUE)

corr_NDVI = filter(corr_res_long, env == "NDVI")
corr_elev = filter(corr_res_long, env == "Elevation")
colscale = c("dark orange2","yellow","#c51b8a")
limits = aes(ymax = corr_res_long$CIupper, ymin=corr_res_long$CIlower)
# no variation - add in CIS?
l = ggplot(data=corr_res_long, aes(factor(env), value, fill = class, alpha = 0.7))+ geom_bar(width = 0.8, position = position_dodge(width = 0.9), stat="identity")+ scale_fill_manual(values = c("All" = "dark orange2","Trans" = "#c51b8a","Ntrans" = "yellow"), labels = c("All species","Excluding transients", "Transients only"))+ geom_bar(data=corr_res_long, aes(factor(env), value, fill = class), width = 0.8, position = position_dodge(width = 0.9), stat="identity")+ geom_errorbar(aes(ymin = corr_res_long$CIlower, ymax = corr_res_long$CIupper), width =.1, position = position_dodge(.9))+ theme_classic() + theme(axis.text.x=element_text(size=30, color = "black"), axis.ticks.x=element_blank(),axis.text.y=element_text(size=30, color = "black"),axis.title.x=element_text(size=40),axis.title.y=element_text(size=40,angle=90,vjust = 2))+ xlab(NULL) + ylab(expression(paste(italic("r")))) + scale_y_continuous(breaks=c(-0.5,-0.3,-0.1,.1,.3,.5))+ guides(fill=guide_legend(title=NULL)) + theme(legend.text = element_text(size = 16)) + geom_hline(yintercept=0, lty = "dashed", lwd = 1.25)
four_b <- l

#### Figure 4c ####
turnover = read.csv("output/tabular_data/temporal_turnover_25.csv", header = TRUE)
turnover_taxa = merge(turnover,dataformattingtable[,c("dataset_ID", "taxa")], by.x = "datasetID", by.y = "dataset_ID")
turnover_col = merge(turnover_taxa, taxcolors, by = "taxa")

# bbs column for diff point symbols
turnover_col$bbs =ifelse(turnover_col$datasetID == 1, "yes", "no")
turnover_bbs = filter(turnover_col, bbs == "yes")
turnover_else = filter(turnover_col, bbs == "no")

turnover_else$taxa = factor(turnover_else$taxa,
                           levels = c('Invertebrate','Fish','Plankton','Mammal','Plant','Bird'),ordered = TRUE)

colscale = c("gold2","turquoise2", "red", "purple4","forestgreen","#1D6A9B") 

m <- ggplot(turnover_else, aes(x = TJ, y = TJnotrans))
four_c <-m + geom_abline(intercept = 0,slope = 1, lwd =1.5,linetype="dashed")+geom_point(aes(colour = taxa), size = 5)+ geom_point(data = turnover_bbs, aes(colour = taxa),size = 2) + xlab("Turnover\n(all species)") + ylab("Turnover\n(excluding transients)")  + scale_colour_manual(breaks = turnover_col$taxa,values = colscale) + theme_classic() + theme(axis.text.x=element_text(size=30,color = "black"),axis.text.y=element_text(size=30,color = "black"),axis.ticks.x=element_blank(),axis.title.x=element_text(size=40),axis.title.y=element_text(size=40,angle=90,vjust = 2))+ guides(colour = guide_legend(title = "Taxa"))


##### Figure 4d ##### only scaled vars
bbs_uniq_area = bbs_abun_occ %>% dplyr::select(stateroute,scale,subrouteID,area) %>% unique()

notransbbsscale = bbs_abun_occ %>% filter(occupancy > 1/4) %>% dplyr::count(stateroute, scale, subrouteID)
names(notransbbsscale) = c("stateroute", "scale", "subrouteID","notrans")
noarea = left_join(notransbbsscale, bbs_uniq_area)

allbbsscale = bbs_abun_occ %>% dplyr::count(stateroute, scale, subrouteID) 
names(allbbsscale) = c("stateroute", "scale","subrouteID", "spRich")
allarea = left_join(allbbsscale, bbs_uniq_area)

bbs_occ_scale = merge(allarea, noarea, by = c("stateroute", "scale", "subrouteID", "area"))
bbs_occ_scale$subrouteID = gsub("Stop", "", bbs_occ_scale$subrouteID)
bbs_occ_scale$site = paste(bbs_occ_scale$stateroute, bbs_occ_scale$scale, bbs_occ_scale$subrouteID, sep = "-")



scaleIDs = unique(bbs_occ_scale$stateroute)
slopes_bbs = data.frame(stateroute = NULL,
                    site = NULL,
                    taxa = NULL,
                    areaSlope = NULL,
                    areaSlope_noTrans = NULL)
for(id in scaleIDs){
  print(id)
  plotsub = subset(bbs_occ_scale,stateroute == id) 
  site = plotsub$site
  taxa = "Bird"
  mod.t = lm(log10(plotsub$spRich) ~ log10(plotsub$area))
  mod.t.slope = summary(mod.t)$coef[2,"Estimate"]
  mod.n= lm(log10(plotsub$notrans) ~ log10(plotsub$area))
  mod.n.slope = summary(mod.n)$coef[2,"Estimate"]
  print(mod.n.slope)
  taxcolor = subset(taxcolors, taxa == as.character(plotsub$taxa)[1])
  slopes_bbs = rbind(slopes_bbs, data.frame(stateroute = id,
                                    site = site,
                                    taxa = taxa,
                                    areaSlope = mod.t.slope, 
                                    areaSlope_noTrans = mod.n.slope))
}
slopes_bbs$bbs = 'yes'

slopes_bbs$datasetID = 1
slopes_bbs = slopes_bbs[,c("datasetID","taxa","areaSlope", "areaSlope_noTrans", "bbs")]

# merge sp rich and minus trans sprich other datasets
notransrich$notrans = notransrich$n

datasetrich = merge(allrich, notransrich[,c("datasetID", "site", "scale","notrans")], by = c("datasetID", "site", "scale"), all.x = TRUE)
colnames(datasetrich)[4] <- "spRich" # rename a single column - make sure index is right

occ_trans_area = merge(areamerge[,c("datasetID", "site", "area")], datasetrich, by = c("datasetID", "site"))
occ_trans_area = merge(occ_trans_area, dataformattingtable[,c("dataset_ID", "taxa")], by.x = "datasetID", by.y = "dataset_ID")
scaleIDs = unique(occ_trans_area$datasetID)

scaleIDs = scaleIDs[! scaleIDs %in% c(279,225,248,254,274, 282,291)] # 248 tbd

slopes = data.frame(datasetID = NULL,
                    taxa = NULL,
                    areaSlope = NULL,
                    areaSlope_noTrans = NULL)
for(id in scaleIDs){
  print(id)
  plotsub = subset(occ_trans_area,datasetID == id) 
  taxa = as.character(unique(plotsub$taxa))
  mod.t = lm(log10(plotsub$spRich) ~ log10(plotsub$area))
  mod.t.slope = summary(mod.t)$coef[2,"Estimate"]
  mod.n= lm(log10(plotsub$notrans) ~ log10(plotsub$area))
  mod.n.slope = summary(mod.n)$coef[2,"Estimate"]
  print(mod.n.slope)
  taxcolor = subset(taxcolors, taxa == as.character(plotsub$taxa)[1])
  slopes = rbind(slopes, data.frame(datasetID = id,
                                    taxa = taxa,
                                    areaSlope = mod.t.slope, 
                                    areaSlope_noTrans = mod.n.slope))
}
slopes$bbs = 'no'

all_slopes =  rbind(slopes, slopes_bbs)

plot_relationship = merge(slopes, taxcolors, by = "taxa")
slopes_bbs = merge(slopes_bbs, taxcolors, by = "taxa")

plot_relationship$taxa = factor(plot_relationship$taxa,
                                levels = c('Invertebrate','Fish','Plankton','Mammal','Plant','Bird','Benthos'),ordered = TRUE)
colscales = c("gray","#1D6A9B","turquoise2","gold2","purple4","red", "forestgreen") 

p <- ggplot(plot_relationship, aes(x = areaSlope, y = areaSlope_noTrans))
four_d <-p + geom_abline(intercept = 0,slope = 1, lwd =1.5,linetype="dashed") +geom_point(data=slopes_bbs, aes(colour = taxa),alpha = 5/100, size = 2)+  geom_point(aes(colour = taxa), size = 5)+ theme_classic() + scale_color_manual("Taxa", breaks = plot_relationship$taxa,values = colscales)+ xlab(expression(paste(italic("z "), "(all species)"))) + ylab(expression(paste(italic("z "), "(excluding transients)"))) +ylim(0,1)+xlim(0,1) + theme(axis.text.x=element_text(size=30,color = "black"),axis.ticks.x=element_blank(),axis.text.y=element_text(size=30,color = "black"),axis.title.x=element_text(size=40),axis.title.y=element_text(size=40,angle=90,vjust = 2))+ theme(legend.text = element_text(size = 14), legend.title = element_text(size = 16))


# make a gridded plot
get_legend<-function(myggplot){
  tmp <- ggplot_gtable(ggplot_build(myggplot))
  leg <- which(sapply(tmp$grobs, function(x) x$name) == "guide-box")
  legend <- tmp$grobs[[leg]]
  return(legend)
}
legenda <- get_legend(l)# + theme(legend.position="top")
p1 = NULL
pt1 <- plot_grid(k + theme(legend.position="none"),
                 NULL,
                 l + theme(legend.position="none"),
                 align = 'hv',
                 labels = c("A","", "B"),
                 label_size = 25,
                 hjust = -11,
                 rel_widths = c(1, 0.05, 1),
                 nrow = 1
)
p1 = plot_grid(pt1,legenda, ncol = 2, rel_widths = c(1, .1))
# ggsave(file="C:/Git/core-transient/output/plots/4a_4b.pdf", height = 10, width = 15,p1)

# c & d
legendc <- get_legend(four_d)
z <- plot_grid(four_c+ theme(legend.position="none"),
               NULL,
               four_d + theme(legend.position="none"),
               align = 'hv',
               labels = c("C","", "D"),
               label_size = 25,
               hjust = -11,
               rel_widths = c(1, 0.05, 1),
               nrow = 1)
p2 = plot_grid(z,legendc, ncol = 2) 

all4 = plot_grid(pt1, NULL, z, align = "hv", nrow = 2,rel_heights = c(1,1), rel_widths = c(1, 0.05, 1))
ggsave(file="C:/Git/core-transient/output/plots/5a_5d_25.pdf", height = 12, width = 16,all4)


##### 10  ######
# Read in datasets
taxcolors = read.csv("output/tabular_data/taxcolors.csv", header = TRUE)
occ_taxa = read.csv("output/tabular_data/occ_taxa_10.csv", header = TRUE)
areamerge = read.csv("output/tabular_data/areamerge.csv", header = TRUE)
allrich = read.csv("output/tabular_data/allrich.csv", header = TRUE)
notransrich = read.csv("output/tabular_data/notransrich_10.csv", header = TRUE)
bbs_abun_occ = read.csv("data/BBS/bbs_abun_occ.csv", header = TRUE)
bbs_occ = read.csv("data/BBS/bbs_abun4_spRich.csv", header = TRUE)
summ10 = read.csv('output/tabular_data/core-transient_summary_10.csv', header=T)
# addings symbols to taxcolors
symbols = c(15, 16, 15, 17, 16, 15, 16) 
Type = c("Invertebrate", "Vertebrate", "Invertebrate", "Plant", "Vertebrate", "Invertebrate", "Vertebrate") 
taxcolors = cbind(taxcolors, Type,symbols)

# calc bbs with and without trans
notransbbs = bbs_abun_occ %>% filter(occupancy > 1/10) %>% dplyr::count(stateroute, scale) %>% filter(scale == 50)
names(notransbbs) = c("stateroute", "scale", "spRichnotrans")

allbbs = bbs_abun_occ %>% dplyr::count(stateroute, scale) %>% filter(scale == 50)
names(allbbs) = c("stateroute", "scale", "spRich")

# Figure 4a in sep script
#' Get list of dataset IDS for datasets that meet criteria for analysis including:
#' * Study wide criteria
#' * Has raw abundance data (not cover or density)
get_valid_datasetIDs = function(){
  dataformattingtable = read.csv('data_formatting_table.csv')
  datasetIDs = dataformattingtable %>%
    filter(format_flag == 1, countFormat %in% c('count', 'abundance')) %>% 
    # Remove count datasets with decimal values
    filter(!dataset_ID %in% c(226, 228, 247, 264, 298, 299, 300, 301)) %>%
    # exclude BBS for now and analyze it separately
    filter(dataset_ID !=1) %>% 
    dplyr::select(dataset_ID)
}

#' Get table of species abundances
#' 
get_abund_data  = function(datasetIDs){
  datasetIDs = datasetIDs$dataset_ID
  dataset_path = 'data/standardized_datasets/'
  abund_data = data.frame()
  for (dataset in datasetIDs){
    filename = paste('dataset_', dataset, '.csv', sep = '')
    print(paste("Loading:", filename))
    site_data = read.csv(file.path(dataset_path, filename), stringsAsFactors = FALSE, fileEncoding = 'latin1')
    abund_data = rbind(abund_data, site_data)
  }
  # Strip zeros which are included to document a sampling event occurred
  abund_data = abund_data[abund_data$count != 0,]
  return(abund_data)
}

#' Get table of species proportional occupancies
#' 
get_propocc_data  = function(datasetIDs){
  datasetIDs = datasetIDs$dataset_ID
  dataset_path = 'data/propOcc_datasets/'
  propocc_data = data.frame()
  for (dataset in datasetIDs){
    filename = paste('propOcc_', dataset, '.csv', sep = '')
    print(paste("Loading:", filename))
    site_data = read.csv(file.path(dataset_path, filename), stringsAsFactors = FALSE, fileEncoding = 'latin1')
    propocc_data = rbind(propocc_data, site_data)
  }
  return(propocc_data)
}


#' Sum the abundances for each species-site combination across years
sum_abunds = function(abund_data){
  summed_abunds = abund_data %>%
    group_by(datasetID, site, species) %>%
    dplyr::summarize(abunds = sum(count)) %>%
    filter(abunds != 0)
  return(summed_abunds)
}

sad_examp = c(109, 14, 4, 4, 680, 195, 13, 3, 123, 116, 1, 5, 105, 26, 14, 2, 9, 29, 15, 133, 5, 41, 45, 33, 
              17, 27, 37, 11, 169, 1, 27, 7, 19, 23, 100, 4, 8, 5, 19, 1, 21, 12, 6, 1, 10, 2, 1, 94, 2, 4, 28, 1, 3, 
              34, 3, 20, 72, 21, 1, 84, 10, 528, 18, 1, 1, 10, 10, 48, 7)

#' Get the AICc weight for the log-series compared to the Poisson log-normal
#' abundance distribution
#' 
#' @param abunds vector of abundances
#' 
#' @return vector of weights for the log-series
#' 
#' @examples 
#' get_sad_weights(c(10, 20, 5, 1, 1, 2, 3, 7))
get_logseries_weight = function(abunds){
  stopifnot(all(abunds == floor(abunds))) # Check that all values are counts
  abunds = abunds[abunds != 0] # SADs are fit only on species that are present
  tryCatch({
    fits = c(fitsad(abunds, 'ls'), fitsad(abunds, 'poilog'))
    aics = sapply(fits, AICc)
    min_aic = min(aics)
    deltas = aics - min_aic
    rellike = exp(-0.5 * deltas)
    weights = rellike / sum(rellike)
    logseries_weight = weights[1]
    return(logseries_weight)
  }, error = function(e) {
    logseries_weight = NA
    return(logseries_weight)
  }
  )
}

datasetIDs = get_valid_datasetIDs()
abund_data = get_abund_data(datasetIDs)
propocc_data = get_propocc_data(datasetIDs)
summed_abunds = sum_abunds(abund_data)
sad_data = left_join(summed_abunds, propocc_data, by = c('datasetID', 'site', 'species'))

logseries_weights_incl = sad_data %>%
  group_by(datasetID, site) %>% 
  dplyr::summarize(weights = get_logseries_weight(abunds), treatment = 'All\nspecies')

logseries_weights_excl = sad_data %>%
  filter(propOcc > 1/10) %>%
  group_by(datasetID, site) %>% 
  dplyr::summarize(weights = get_logseries_weight(abunds), treatment = 'Excluding\ntransients')

logseries_weights = rbind(logseries_weights_incl, logseries_weights_excl)
# write.csv(logseries_weights, "output/tabular_data/logseries_weights.csv")
# logseries_weights = read.csv("output/tabular_data/logseries_weights.csv", header = TRUE)
colscale = c("dark orange2","yellow")
k = ggplot(logseries_weights,aes(x=weights,fill=treatment))+geom_histogram(bins = 20, position = "identity", alpha = 0.7)+ xlab("Transient Status") + ylab("Proportion of Species") + scale_y_continuous(breaks=c(0,50,100, 150)) + scale_fill_manual(labels = c("All species","All species excluding transients"),values = colscale)+ theme_classic() + theme(axis.text.x=element_blank(), axis.ticks.x=element_blank(),axis.text.y=element_text(size=30, color = "black"),axis.title.y=element_text(size=40,angle=90,vjust = 5),axis.title.x=element_text(size=40, vjust = -7))  + ylab("Frequency") + xlab("Akaike Weight") + theme(legend.position = "none") +theme(plot.margin=unit(c(0.35,1,2,1.7),"cm")) 

#### Figure 4b ####
# read in route level ndvi and elevation data (radius = 40 km)
# we want to agg by month here
gimms_ndvi = read.csv("output/tabular_data/gimms_ndvi_bbs_data.csv", header = TRUE)
gimms_agg = gimms_ndvi %>% filter(month == c("may", "jun", "jul")) %>% 
  group_by(site_id)  %>%  dplyr::summarise(ndvi=mean(ndvi))

lat_scale_rich = read.csv("output/tabular_data/lat_scale_rich_10.csv", header = TRUE)
lat_scale_bbs = filter(lat_scale_rich, datasetID == 1)
lat_scale_bbs$site_id = sapply(strsplit(as.character(lat_scale_bbs$site), split='-', fixed=TRUE), function(x) (x[1]))
lat_scale_bbs$site_id = as.integer(lat_scale_bbs$site_id)

lat_scale_test = filter(lat_scale_bbs, datasetID == 1) %>% separate(., site, c("stateroute", "level", "number"), sep = "-") %>% filter(., level == 50)
lat_scale_test$site = lat_scale_test$stateroute

bbsocc = read.csv('data/propOcc_datasets/propOcc_1.csv', header=T, stringsAsFactors = F)
rich = dplyr::count(bbsocc, site)
rich_notrans = bbsocc %>% filter(propOcc > 1/10) %>% count(site)

bbsocc_rich = left_join(bbsocc, rich)
bbsocc_rich$spRich = bbsocc_rich$n
bbsocc_rich = bbsocc_rich[ , !names(bbsocc_rich) %in% c("n")] 
bbsocc_rich = left_join(bbsocc_rich, rich_notrans)
bbsocc_rich$spRichnotrans = bbsocc_rich$n
bbsocc_rich = bbsocc_rich[ , !names(bbsocc_rich) %in% c("n")] 

bbs_env = left_join(bbsocc_rich, gimms_agg, c("site" = "site_id"))
bbs_env = merge(bbs_env, lat_scale_test[,c("stateroute", "elev.point", "elev.mean", "elev.var")], by.x = "site", by.y = "stateroute")

# cor test not really working - need for loop?
cor.test(bbs_env$spRich, bbs_env$ndvi)
bar1 = cor.test(bbs_env$spRich, bbs_env$ndvi)$estimate
CI1lower =  cor.test(bbs_env$spRich, bbs_env$ndvi)$conf.int[1]
CI1upper = cor.test(bbs_env$spRich, bbs_env$ndvi)$conf.int[2]
bar3 = cor.test(bbs_env$spRich, bbs_env$elev.mean)$estimate
CI3lower = cor.test(bbs_env$spRich, bbs_env$elev.mean)$conf.int[1]
CI3upper =  cor.test(bbs_env$spRich, bbs_env$elev.mean)$conf.int[2]

bar2 = cor.test(bbs_env$spRichnotrans, bbs_env$ndvi)$estimate
CI2lower = cor.test(bbs_env$spRichnotrans, bbs_env$ndvi)$conf.int[1]
CI2upper =   cor.test(bbs_env$spRichnotrans, bbs_env$ndvi)$conf.int[2]
bar4 = cor.test(bbs_env$spRichnotrans, bbs_env$elev.mean)$estimate
CI4lower =  cor.test(bbs_env$spRichnotrans, bbs_env$elev.mean)$conf.int[1]
CI4upper =  cor.test(bbs_env$spRichnotrans, bbs_env$elev.mean)$conf.int[2]

bar5 = cor.test(bbs_env$spRich-bbs_env$spRichnotrans, bbs_env$ndvi)$estimate
CI5lower = cor.test(bbs_env$spRich-bbs_env$spRichnotrans, bbs_env$ndvi)$conf.int[1]
CI5upper =  cor.test(bbs_env$spRich-bbs_env$spRichnotrans, bbs_env$ndvi)$conf.int[2]
bar6 = cor.test(bbs_env$spRich-bbs_env$spRichnotrans, bbs_env$elev.mean)$estimate
CI6lower = cor.test(bbs_env$spRich-bbs_env$spRichnotrans, bbs_env$elev.mean)$conf.int[1]
CI6upper =  cor.test(bbs_env$spRich-bbs_env$spRichnotrans, bbs_env$elev.mean)$conf.int[2]

corr_res <- data.frame(All = c(bar1, bar3), Ntrans = c(bar2, bar4), Trans = c(bar5, bar6)) 
corr_res$env = c("NDVI", "Elevation")
corr_res_long = gather(corr_res, "class","value", c(All:Trans))
corr_res_long$CIlower = c(CI1lower,CI3lower,CI2lower,CI4lower, CI5lower, CI6lower)
corr_res_long$CIupper = c(CI1upper,CI3upper,CI2upper,CI4upper, CI5upper, CI6upper)
corr_res_long$env = factor(corr_res_long$env, levels = c("NDVI", "Elevation"), ordered = TRUE)

corr_NDVI = filter(corr_res_long, env == "NDVI")
corr_elev = filter(corr_res_long, env == "Elevation")
colscale = c("dark orange2","yellow","#c51b8a")
limits = aes(ymax = corr_res_long$CIupper, ymin=corr_res_long$CIlower)
# no variation - add in CIS?
l = ggplot(data=corr_res_long, aes(factor(env), value, fill = class, alpha = 0.7))+ geom_bar(width = 0.8, position = position_dodge(width = 0.9), stat="identity")+ scale_fill_manual(values = c("All" = "dark orange2","Trans" = "#c51b8a","Ntrans" = "yellow"), labels = c("All species","Excluding transients", "Transients only"))+ geom_bar(data=corr_res_long, aes(factor(env), value, fill = class), width = 0.8, position = position_dodge(width = 0.9), stat="identity")+ geom_errorbar(aes(ymin = corr_res_long$CIlower, ymax = corr_res_long$CIupper), width =.1, position = position_dodge(.9))+ theme_classic() + theme(axis.text.x=element_text(size=30, color = "black"), axis.ticks.x=element_blank(),axis.text.y=element_text(size=30, color = "black"),axis.title.x=element_text(size=40),axis.title.y=element_text(size=40,angle=90,vjust = 2))+ xlab(NULL) + ylab(expression(paste(italic("r")))) + scale_y_continuous(breaks=c(-0.5,-0.3,-0.1,.1,.3,.5))+ guides(fill=guide_legend(title=NULL)) + theme(legend.text = element_text(size = 16)) + geom_hline(yintercept=0, lty = "dashed", lwd = 1.25)
four_b <- l

#### Figure 4c ####
turnover = read.csv("output/tabular_data/temporal_turnover_10.csv", header = TRUE)
turnover_taxa = merge(turnover,dataformattingtable[,c("dataset_ID", "taxa")], by.x = "datasetID", by.y = "dataset_ID")
turnover_col = merge(turnover_taxa, taxcolors, by = "taxa")

# bbs column for diff point symbols
turnover_col$bbs =ifelse(turnover_col$datasetID == 1, "yes", "no")
turnover_bbs = filter(turnover_col, bbs == "yes")
turnover_else = filter(turnover_col, bbs == "no")

turnover_else$taxa = factor(turnover_else$taxa,
                            levels = c('Invertebrate','Fish','Plankton','Mammal','Plant','Bird'),ordered = TRUE)

colscale = c("gold2","turquoise2", "red", "purple4","forestgreen","#1D6A9B") 

m <- ggplot(turnover_else, aes(x = TJ, y = TJnotrans))
four_c <-m + geom_abline(intercept = 0,slope = 1, lwd =1.5,linetype="dashed")+geom_point(aes(colour = taxa), size = 5)+ geom_point(data = turnover_bbs, aes(colour = taxa),size = 2) + xlab("Turnover\n(all species)") + ylab("Turnover\n(excluding transients)")  + scale_colour_manual(breaks = turnover_col$taxa,values = colscale) + theme_classic() + theme(axis.text.x=element_text(size=30,color = "black"),axis.text.y=element_text(size=30,color = "black"),axis.ticks.x=element_blank(),axis.title.x=element_text(size=40),axis.title.y=element_text(size=40,angle=90,vjust = 2))+ guides(colour = guide_legend(title = "Taxa"))


##### Figure 4d ##### only scaled vars
bbs_uniq_area = bbs_abun_occ %>% dplyr::select(stateroute,scale,subrouteID,area) %>% unique()

notransbbsscale = bbs_abun_occ %>% filter(occupancy > 1/4) %>% dplyr::count(stateroute, scale, subrouteID)
names(notransbbsscale) = c("stateroute", "scale", "subrouteID","notrans")
noarea = left_join(notransbbsscale, bbs_uniq_area)

allbbsscale = bbs_abun_occ %>% dplyr::count(stateroute, scale, subrouteID) 
names(allbbsscale) = c("stateroute", "scale","subrouteID", "spRich")
allarea = left_join(allbbsscale, bbs_uniq_area)

bbs_occ_scale = merge(allarea, noarea, by = c("stateroute", "scale", "subrouteID", "area"))
bbs_occ_scale$subrouteID = gsub("Stop", "", bbs_occ_scale$subrouteID)
bbs_occ_scale$site = paste(bbs_occ_scale$stateroute, bbs_occ_scale$scale, bbs_occ_scale$subrouteID, sep = "-")



scaleIDs = unique(bbs_occ_scale$stateroute)
slopes_bbs = data.frame(stateroute = NULL,
                        site = NULL,
                        taxa = NULL,
                        areaSlope = NULL,
                        areaSlope_noTrans = NULL)
for(id in scaleIDs){
  print(id)
  plotsub = subset(bbs_occ_scale,stateroute == id) 
  site = plotsub$site
  taxa = "Bird"
  mod.t = lm(log10(plotsub$spRich) ~ log10(plotsub$area))
  mod.t.slope = summary(mod.t)$coef[2,"Estimate"]
  mod.n= lm(log10(plotsub$notrans) ~ log10(plotsub$area))
  mod.n.slope = summary(mod.n)$coef[2,"Estimate"]
  print(mod.n.slope)
  taxcolor = subset(taxcolors, taxa == as.character(plotsub$taxa)[1])
  slopes_bbs = rbind(slopes_bbs, data.frame(stateroute = id,
                                            site = site,
                                            taxa = taxa,
                                            areaSlope = mod.t.slope, 
                                            areaSlope_noTrans = mod.n.slope))
}
slopes_bbs$bbs = 'yes'

slopes_bbs$datasetID = 1
slopes_bbs = slopes_bbs[,c("datasetID","taxa","areaSlope", "areaSlope_noTrans", "bbs")]

# merge sp rich and minus trans sprich other datasets
notransrich$notrans = notransrich$n

datasetrich = merge(allrich, notransrich[,c("datasetID", "site", "scale","notrans")], by = c("datasetID", "site", "scale"), all.x = TRUE)
colnames(datasetrich)[4] <- "spRich" # rename a single column - make sure index is right

occ_trans_area = merge(areamerge[,c("datasetID", "site", "area")], datasetrich, by = c("datasetID", "site"))
occ_trans_area = merge(occ_trans_area, dataformattingtable[,c("dataset_ID", "taxa")], by.x = "datasetID", by.y = "dataset_ID")
scaleIDs = unique(occ_trans_area$datasetID)

scaleIDs = scaleIDs[! scaleIDs %in% c(279,225,248,254,274, 282,291)] # 248 tbd

slopes = data.frame(datasetID = NULL,
                    taxa = NULL,
                    areaSlope = NULL,
                    areaSlope_noTrans = NULL)
for(id in scaleIDs){
  print(id)
  plotsub = subset(occ_trans_area,datasetID == id) 
  taxa = as.character(unique(plotsub$taxa))
  mod.t = lm(log10(plotsub$spRich) ~ log10(plotsub$area))
  mod.t.slope = summary(mod.t)$coef[2,"Estimate"]
  mod.n= lm(log10(plotsub$notrans) ~ log10(plotsub$area))
  mod.n.slope = summary(mod.n)$coef[2,"Estimate"]
  print(mod.n.slope)
  taxcolor = subset(taxcolors, taxa == as.character(plotsub$taxa)[1])
  slopes = rbind(slopes, data.frame(datasetID = id,
                                    taxa = taxa,
                                    areaSlope = mod.t.slope, 
                                    areaSlope_noTrans = mod.n.slope))
}
slopes$bbs = 'no'

all_slopes =  rbind(slopes, slopes_bbs)

plot_relationship = merge(slopes, taxcolors, by = "taxa")
slopes_bbs = merge(slopes_bbs, taxcolors, by = "taxa")

plot_relationship$taxa = factor(plot_relationship$taxa,
                                levels = c('Invertebrate','Fish','Plankton','Mammal','Plant','Bird','Benthos'),ordered = TRUE)
colscales = c("gray","#1D6A9B","turquoise2","gold2","purple4", "red", "forestgreen") 

p <- ggplot(plot_relationship, aes(x = areaSlope, y = areaSlope_noTrans))
four_d <-p + geom_abline(intercept = 0,slope = 1, lwd =1.5,linetype="dashed") +geom_point(data=slopes_bbs, aes(colour = taxa),alpha = 5/100, size = 2)+  geom_point(aes(colour = taxa), size = 5)+ theme_classic() + scale_color_manual("Taxa", breaks = plot_relationship$taxa,values = colscales)+ xlab(expression(paste(italic("z "), "(all species)"))) + ylab(expression(paste(italic("z "), "(excluding transients)"))) +ylim(0,1)+xlim(0,1) + theme(axis.text.x=element_text(size=30,color = "black"),axis.ticks.x=element_blank(),axis.text.y=element_text(size=30,color = "black"),axis.title.x=element_text(size=40),axis.title.y=element_text(size=40,angle=90,vjust = 2))+ theme(legend.text = element_text(size = 14), legend.title = element_text(size = 16))


# make a gridded plot
get_legend<-function(myggplot){
  tmp <- ggplot_gtable(ggplot_build(myggplot))
  leg <- which(sapply(tmp$grobs, function(x) x$name) == "guide-box")
  legend <- tmp$grobs[[leg]]
  return(legend)
}
legenda <- get_legend(l)# + theme(legend.position="top")
p1 = NULL
pt1 <- plot_grid(k + theme(legend.position="none"),
                 NULL,
                 l + theme(legend.position="none"),
                 align = 'hv',
                 labels = c("A","", "B"),
                 label_size = 25,
                 hjust = -11,
                 rel_widths = c(1, 0.05, 1),
                 nrow = 1
)
p1 = plot_grid(pt1,legenda, ncol = 2, rel_widths = c(1, .1))

# c & d
legendc <- get_legend(four_d)
z <- plot_grid(four_c+ theme(legend.position="none"),
               NULL,
               four_d + theme(legend.position="none"),
               align = 'hv',
               labels = c("C","", "D"),
               label_size = 25,
               hjust = -11,
               rel_widths = c(1, 0.05, 1),
               nrow = 1)
p2 = plot_grid(z,legendc, ncol = 2) 

all4 = plot_grid(pt1, NULL, z, align = "hv", nrow = 2,rel_heights = c(1,1), rel_widths = c(1, 0.05, 1))
ggsave(file="C:/Git/core-transient/output/plots/5a_5d_10.pdf", height = 13, width = 17,all4)

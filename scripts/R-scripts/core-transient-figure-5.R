###############################################
# Code for running core-transient analysis
# and data summaries over all formatted datasets.
#
# Input files are named propOcc_XXX.csv where
# XXX is the dataset ID.

bbsocc = read.csv('data/propOcc_datasets/propOcc_1.csv', header=T, stringsAsFactors = F)
head(bbsocc)
length(unique(bbsocc$site))
rich = dplyr::count(bbsocc, site)
head(rich)
rich_notrans = bbsocc %>% filter(propOcc > 1/3) %>% count(site)
head(rich_notrans)

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
library(grid)

source('scripts/R-scripts/core-transient_functions.R')

# Specify here the datasetIDs and then run the code below.
dataformattingtable = read.csv('data_formatting_table.csv', header = T) 

datasetIDs = dataformattingtable$dataset_ID[dataformattingtable$format_flag == 1]

# BBS (dataset 1) will be analyzed separately for now.
datasetIDs = datasetIDs[!datasetIDs %in% c(1)]

##### prep for all figures #####
# Read in datasets
taxcolors = read.csv("output/tabular_data/taxcolors.csv", header = TRUE)
occ_taxa = read.csv("output/tabular_data/occ_taxa.csv", header = TRUE)
areamerge = read.csv("output/tabular_data/areamerge.csv", header = TRUE)
allrich = read.csv("output/tabular_data/allrich.csv", header = TRUE)
notransrich = read.csv("output/tabular_data/notransrich.csv", header = TRUE)
bbs_abun_occ = read.csv("data/BBS/bbs_abun_occ.csv", header = TRUE)
bbs_occ = read.csv("data/BBS/bbs_abun4_spRich.csv", header = TRUE)
bbs_count = read.csv("data/BBS/bbs_2000_2014.csv", header = TRUE)
bbs_occ_aou = read.csv("data/BBS/bbs_occ_2000_2014.csv", header = TRUE)
bray_output = read.csv("output/tabular_data/temporal_turnover_bray.csv", header = TRUE)

# addings symbols to taxcolors
symbols = c(15, 16, 15, 17, 16, 15, 16) 
Type = c("Invertebrate", "Vertebrate", "Invertebrate", "Plant", "Vertebrate", "Invertebrate", "Vertebrate") 
taxcolors = cbind(taxcolors, Type,symbols)

# calc bbs with and without trans
notransbbs = bbs_abun_occ %>% filter(occupancy > 1/3) %>% dplyr::count(stateroute, scale) %>% filter(scale == 50)
names(notransbbs) = c("stateroute", "scale", "spRichnotrans")

allbbs = bbs_abun_occ %>% dplyr::count(stateroute, scale) %>% filter(scale == 50)
names(allbbs) = c("stateroute", "scale", "spRich")

# create bbs files
bbs_count5a = dplyr::rename(bbs_count, year = Year, site = stateroute, species = aou, count = speciestotal)
bbs_count5a$datasetID = 1
write.csv(bbs_count5a, "data/standardized_datasets/dataset_1.csv", row.names = FALSE)

# bbs_abun_occ1 = subset(bbs_abun_occ, scale ==  50)
bbs_occ_aou = dplyr::rename(bbs_occ_aou, site = stateroute, species = aou, propOcc = occ)
bbs_occ_aou$datasetID  = 1
bbs_occ5a = bbs_occ_aou[, c("datasetID", "site", "species", "propOcc")]
write.csv(bbs_occ5a, "data/propOcc_datasets/propOcc_1.csv", row.names = FALSE)

sad_examp = c(109, 14, 4, 4, 680, 195, 13, 3, 123, 116, 1, 5, 105, 26, 14, 2, 9, 29, 15, 133, 5, 41, 45, 33, 
              17, 27, 37, 11, 169, 1, 27, 7, 19, 23, 100, 4, 8, 5, 19, 1, 21, 12, 6, 1, 10, 2, 1, 94, 2, 4, 28, 1, 3, 
              34, 3, 20, 72, 21, 1, 84, 10, 528, 18, 1, 1, 10, 10, 48, 7)

datasetIDs = get_valid_datasetIDs()
abund_data = get_abund_data(datasetIDs)
propocc_data = get_propocc_data(datasetIDs)
summed_abunds = sum_abunds(abund_data)
sad_data = left_join(summed_abunds, propocc_data, by = c('datasetID', 'site', 'species'))

logseries_weights_incl = sad_data %>%
  group_by(datasetID, site) %>% 
  dplyr::summarize(weights = get_logseries_weight(abunds), treatment = 'All')

logseries_weights_excl = sad_data %>%
  filter(propOcc > 1/3) %>%
  group_by(datasetID, site) %>% 
  dplyr::summarize(weights = get_logseries_weight(abunds), treatment = 'Excluding')


logseries_weights = rbind(logseries_weights_incl, logseries_weights_excl)
# write.csv(logseries_weights, "output/tabular_data/logseries_weights.csv")
logseries_weights = read.csv("output/tabular_data/logseries_weights.csv", header = TRUE)

d = merge(logseries_weights_incl, logseries_weights_excl, by = c("datasetID", "site"), all.x = TRUE)
d$all_weight = d$weights.x 
d$all = d$treatment.x 
d$excl_weight = d$weights.y
d$excl = d$treatment.y 
d = d[, c("datasetID", "site","all_weight", "excl_weight")]
fourataxa = merge(d, dataformattingtable[,c("dataset_ID", "taxa")],by.x = "datasetID", by.y = "dataset_ID")
fourataxa = merge(fourataxa, taxcolors, by = "taxa")

#### plot 5a ####
colscale = c("dark orange2","yellow")
k = ggplot(logseries_weights,aes(x=weights,fill=treatment))+geom_histogram(bins = 20, position = "identity", alpha = 0.7)+ xlab("Transient Status") + ylab("Proportion of Species") + scale_y_continuous(breaks=c(0,400,800,1200)) + scale_fill_manual(labels = c("All species","All species excluding transients"),values = colscale)+ theme_classic() + theme(axis.text.x=element_blank(), axis.ticks.x=element_blank(),axis.text.y=element_text(size=30, color = "black"),axis.title.y=element_text(size=46,angle=90,vjust = 5),axis.title.x=element_text(size=46, vjust = -7))  + ylab("Frequency") + xlab("Akaike Weight") + theme(legend.position = "none") +theme(plot.margin=unit(c(0.35,1,2,1.7),"cm")) 
# pdf("output/plots/fig1a.pdf", height = 8, width = 10)
k
grid.text("lognormal",
          x = unit(.24, "npc"), y = unit(0.2, "npc"), just = c("left", "bottom"), 
          gp = gpar(fontface = "bold", fontsize = 18, col = "black"))
grid.text("logseries",
          x = unit(.95, "npc"), y = unit(0.2, "npc"), just = c("right", "bottom"), 
          gp = gpar(fontface = "bold", fontsize = 18, col = "black"))
dev.off()


#### Figure 5b ####
# read in route level ndvi and elevation data (radius = 40 km)
# we want to agg by month here
rich = dplyr::count(bbsocc, site)
rich_notrans = bbsocc %>% filter(propOcc > 1/3) %>% count(site)

bbsocc_rich = left_join(bbsocc, rich)
bbsocc_rich$spRich = bbsocc_rich$n
bbsocc_rich = bbsocc_rich[ , !names(bbsocc_rich) %in% c("n")] 
bbsocc_rich = left_join(bbsocc_rich, rich_notrans)
bbsocc_rich$spRichnotrans = bbsocc_rich$n
bbsocc_rich = bbsocc_rich[ , !names(bbsocc_rich) %in% c("n")] 

bbs_env = left_join(bbsocc_rich, gimms_agg, c("site" = "site_id"))
bbs_env = merge(bbs_env, lat_scale_bbs[,c("site", "elev.point", "elev.mean", "elev.var")], by = "site")

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
l = ggplot(data=corr_res_long, aes(factor(env), value, fill = class, alpha = 0.7))+ geom_bar(width = 0.8, position = position_dodge(width = 0.9), stat="identity")+ scale_fill_manual(values = c("All" = "dark orange2","Trans" = "#c51b8a","Ntrans" = "yellow"), labels = c("All species","Excluding transients", "Transients only"))+ geom_bar(data=corr_res_long, aes(factor(env), value, fill = class), width = 0.8, position = position_dodge(width = 0.9), stat="identity")+ geom_errorbar(aes(ymin = corr_res_long$CIlower, ymax = corr_res_long$CIupper), width =.1, position = position_dodge(.9))+ theme_classic() + theme(axis.text.x=element_text(size=46, color = "black", vjust = 5), axis.ticks.x=element_blank(),axis.text.y=element_text(size=30, color = "black"),axis.title.x=element_text(size=46, color = "black"),axis.title.y=element_text(size=46,angle=90,vjust = 2))+ xlab(NULL) + ylab(expression(paste(italic("r")))) + scale_y_continuous(breaks=c(-0.5,-0.3,-0.1,.1,.3,.5))+ guides(fill=guide_legend(title=NULL)) + theme(legend.text = element_text(size = 38), legend.title = element_blank(), legend.key.height=unit(3,"line")) + geom_hline(yintercept=0, lty = "dashed", lwd = 1.25) + theme(plot.margin=unit(c(1,1,2,1),"cm"))
four_b <- l
# ggsave(file="C:/Git/core-transient/output/plots/5b_corrcoeff_NDVI.pdf", height = 5, width = 15)

#### test for fig 1 new #####
mh = read.csv("data/raw_datasets/dataset_255RAW/MHfig1.csv", header = TRUE)
mh$class = factor(mh$class, levels = c('trans','core'),ordered = TRUE)

ggplot(mh, aes(x=abunx, freqy,fill=factor(class))) + geom_bar(stat="identity", position = "identity",color = "gray50", alpha = 0.5, lwd = 1.05)+ ylab("Frequency") + xlab ("Maximum abundance")  + scale_x_continuous(breaks = c(1,4, 8, 11, 15), labels = c("1","10","100","1,000","10,000"))+ scale_fill_manual(labels = c("Transient", "Core"),values = c("white","gray0"))+ theme_classic() + theme(axis.text.x=element_text(size=40, color = "black"),axis.text.y=element_text(size=40, color = "black"),axis.title.x=element_text(size=50, color = "black"),axis.title.y=element_text(size=50,angle=90,vjust = 3.5)) +theme(legend.justification=c(0, 1))+ guides(fill = guide_legend(keywidth = 3, keyheight = 3,title="")) +  theme(legend.text = element_text(size = 30)) 

ggsave(file="C:/Git/core-transient/output/plots/1b_M_H_hists.pdf", height = 10, width = 16)

#### Figure 5c ####
turnover = read.csv("output/tabular_data/temporal_turnover.csv", header = TRUE)
turnover_taxa = merge(turnover,dataformattingtable[,c("dataset_ID", "taxa")], by.x = "datasetID", by.y = "dataset_ID")
turnover_col = merge(turnover_taxa, taxcolors, by = "taxa")

bray_taxa = merge(bray_output,dataformattingtable[,c("dataset_ID", "taxa")], by.x = "datasetID", by.y = "dataset_ID")
bray_col = merge(bray_taxa, taxcolors, by = "taxa")
bray_col$bbs =ifelse(bray_col$datasetID == 1, "yes", "no")
bray_bbs = filter(bray_col, bbs == "yes")
bray_else = filter(bray_col, bbs == "no")

bray_else$taxa = factor(bray_else$taxa,
                            levels = c('Bird','Fish', 'Invertebrate','Mammal','Plankton','Plant'),ordered = TRUE)
# bbs column for diff point symbols
turnover_col$bbs =ifelse(turnover_col$datasetID == 1, "yes", "no")
turnover_bbs = filter(turnover_col, bbs == "yes")
turnover_else = filter(turnover_col, bbs == "no")
turnover_col$diff = turnover_col$TJnotrans-turnover_col$TJ
hist(turnover_col$diff, xlab = "Excluding transients - All species", cex.lab=1.5, cex.axis=1.5)

turnover_else$taxa = factor(turnover_else$taxa,
                            levels = c('Invertebrate','Fish','Plankton','Mammal','Plant','Bird'),ordered = TRUE)

colscale = c("#1D6A9B", "turquoise2","gold2", "purple4","red", "forestgreen") 

# deviation
mean(na.omit(turnover_taxa$TJnotrans) - na.omit(turnover_taxa$TJ))
sd(na.omit(turnover_taxa$TJnotrans) - na.omit(turnover_taxa$TJ))


m <- ggplot(turnover_bbs, aes(x = TJ, y = TJnotrans))
four_c <-m + geom_abline(intercept = 0,slope = 1, lwd =1.5,linetype="dashed")+geom_point(data = turnover_bbs, aes(colour = taxa),size = 2)+geom_point(data = turnover_else, aes(colour = taxa), size = 5) + xlab("Turnover (all species)") + ylab("Turnover \n (excluding transients)")  + scale_colour_manual(breaks = turnover_col$taxa,values = colscale) + theme_classic() + theme(axis.text.x=element_text(size=30, color = "black"),axis.text.y=element_text(size=30, color = "black"),axis.ticks.x=element_blank(),axis.title.x=element_text(size=46, color = "black"),axis.title.y=element_text(size=46,angle=90,vjust = 5))+ guides(colour = guide_legend(title = "Taxa"))


b <- ggplot(bray_bbs, aes(x = TJ, y = TJnotrans))
bray <-b + geom_abline(intercept = 0,slope = 1, lwd =1.5,linetype="dashed")+ geom_point(aes(colour = taxa),size = 2)+geom_point(data = bray_else, aes(colour = taxa), size = 5) + xlab("Bray-Curtis Index (all species)") + ylab("Bray-Curtis \n (excluding transients)")  + scale_colour_manual(breaks = bray_col$taxa,values = colscale) + theme_classic() + theme(axis.text.x=element_text(size=30, color = "black"),axis.text.y=element_text(size=30, color = "black"),axis.ticks.x=element_blank(),axis.title.x=element_text(size=40, color = "black", vjust = 2),axis.title.y=element_text(size=40,angle=90,vjust = 3))+ guides(colour = guide_legend(title = "Taxa"))
ggsave(file="C:/Git/core-transient/output/plots/5s_brayturnover.pdf", height = 10, width = 15)


##### Figure 5d ##### only scaled vars
bbs_uniq_area = bbs_abun_occ %>% dplyr::select(stateroute,scale,subrouteID,area) %>% unique()

notransbbsscale = bbs_abun_occ %>% filter(occupancy > 1/3) %>% dplyr::count(stateroute, scale, subrouteID)
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

scaleIDs = scaleIDs[! scaleIDs %in% c(279,225,248,254, 282,291)] # 248 tbd

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
plot_relationship$diff = plot_relationship$areaSlope_noTrans-plot_relationship$areaSlope
hist(plot_relationship$diff, xlab = "Excluding transients - All Species")

slopes_bbs = merge(slopes_bbs, taxcolors, by = "taxa")

plot_relationship$taxa = factor(plot_relationship$taxa,
                                levels = c('Invertebrate','Fish','Plankton','Mammal','Plant','Bird','Benthos'),ordered = TRUE)
colscales = c("gray","#1D6A9B", "turquoise2","gold2", "purple4","red", "forestgreen") 


# deviation
mean(na.omit(plot_relationship$areaSlope_noTrans) - na.omit(plot_relationship$areaSlope))
sd(na.omit(plot_relationship$areaSlope_noTrans) - na.omit(plot_relationship$areaSlope))


p <- ggplot(plot_relationship, aes(x = areaSlope, y = areaSlope_noTrans))
four_d <-p + geom_abline(intercept = 0,slope = 1, lwd =1.5,linetype="dashed") +geom_point(data=slopes_bbs, aes(colour = taxa),alpha = 5/100, size = 2)+  geom_point(aes(colour = taxa), size = 5)+ theme_classic() + scale_color_manual("Taxa", breaks = plot_relationship$taxa,values = colscales)+ xlab(expression(paste(italic("z "), "(all species)"))) + ylab(expression(paste(italic("z "), "(excluding transients)"))) +ylim(0,1)+xlim(0,1) + theme(axis.text.x=element_text(size=30, color = "black"),axis.ticks.x=element_blank(),axis.text.y=element_text(size=30, color = "black"),axis.title.x=element_text(size=46, color = "black"),axis.title.y=element_text(size=46,angle=90,vjust = 2))+ theme(legend.text = element_text(size = 38), legend.title = element_blank(), legend.key.height=unit(3,"line")) #,legend.position = c(.75, .3))

##### make a gridded plot #####
get_legend<-function(myggplot){
  tmp <- ggplot_gtable(ggplot_build(myggplot))
  leg <- which(sapply(tmp$grobs, function(x) x$name) == "guide-box")
  legend <- tmp$grobs[[leg]]
  return(legend)
}
# a & b
legenda <- get_legend(four_b)
p1 = NULL
pt1 <- plot_grid(k + theme(legend.position="none"),
                 NULL,
                 l + theme(legend.position="none"),
                 align = 'hv',
                 labels = c("A","", "B"),
                 label_size = 36,
                 hjust = -7,
                 rel_widths = c(1, 0.05, 1),
                 nrow = 1)

# c & d
legendc <- get_legend(four_d)
z <- plot_grid(four_c+ theme(legend.position="none"),
               NULL,
               four_d + theme(legend.position="none"),
               align = 'hv',
               labels = c("C","", "D"),
               label_size = 36,
               hjust = -7,
               rel_widths = c(1, 0.05, 1),
               nrow = 1)
p2 = plot_grid(z,legendc, ncol = 2) 

all4 = plot_grid(pt1, NULL, z, align = "hv", nrow = 2,rel_heights = c(1,1), rel_widths = c(1, 0.05,1))
all4
ggsave(file="C:/Git/core-transient/output/plots/5a_5d.pdf", height = 16, width = 22,all4)



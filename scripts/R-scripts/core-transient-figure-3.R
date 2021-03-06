###############################################
# Code for running core-transient analysis
# and data summaries over all formatted datasets.
#
# Input files are named propOcc_XXX.csv where
# XXX is the dataset ID.

setwd("C:/git/core-transient")

library(tidyverse)
library(lme4)
library(plyr) # for core-transient functions
library(gridExtra)
library(agricolae)
library(maps)
library(cowplot)

source('scripts/R-scripts/core-transient_functions.R')

# Specify here the datasetIDs and then run the code below.
dataformattingtable = read.csv('data_formatting_table.csv', header = T) 

datasetIDs = dataformattingtable$dataset_ID[dataformattingtable$format_flag == 1]

# BBS (dataset 1) will be analyzed separately for now.
datasetIDs = datasetIDs[!datasetIDs %in% c(1)]

##### Boxplots showing distribution of core and transient species by taxon #####
# Read in datasets
bbs_abun4 = read.csv("data/BBS/bbs_abun4_spRich.csv", header = TRUE)
bbs_abun4$propTrans = bbs_abun4$pctTrans
bbs_abun4$propCore = bbs_abun4$pctCore
bbs_abun4$system <- "Terrestrial"
bbs_abun4 = bbs_abun4[,c("datasetID", "site","system", "taxa", "propCore", "propTrans", "meanAbundance")]
summ1.5 = read.csv("output/tabular_data/summ1.5.csv", header = TRUE)
taxcolors = read.csv("output/tabular_data/taxcolors.csv", header = TRUE)


# Rbind bbs at stateroute level and summary data together
summ2.5 = rbind(bbs_abun4,summ1.5)

core = summ2.5 %>%
  dplyr::group_by(taxa) %>%
  dplyr::summarize(mean(propCore)) 
trans = summ2.5 %>%
  dplyr::group_by(taxa) %>%
  dplyr::summarize(mean(propTrans)) 

propCT = merge(core, trans, by = "taxa")
propCT = data.frame(propCT)
propCT$mean.propNeither. = 1 - propCT$mean.propCore. - propCT$mean.propTrans.

lm.hsd = lm(mean.propTrans. ~ taxa, data= propCT) #Tukeys HSD
aov(lm.hsd)
# agricolae::HSD.test(lm.hsd, "taxa")

propCT_long = gather(propCT, "class","value", c(mean.propCore.:mean.propNeither.))
propCT_long = arrange(propCT_long, desc(class))
propCT_long$taxa = as.factor(propCT_long$taxa)
propCT_long$taxa = factor(propCT_long$taxa,
         levels = c('Benthos','Invertebrate','Fish','Plankton','Mammal','Plant','Bird'),ordered = TRUE)
colscale = c("#c51b8a", "#fdd49e", "#225ea8")

### Fig 3b
core_e = summ2.5 %>%
  dplyr::group_by(system) %>%
  dplyr::summarize(mean(propCore)) 
trans_e = summ2.5 %>%
  dplyr::group_by(system) %>%
  dplyr::summarize(mean(propTrans)) 

prope = merge(core_e, trans_e, by = "system")
prope = data.frame(prope)
prope$mean.propNeither. = 1 - prope$mean.propCore. - prope$mean.propTrans.

prope_long = gather(prope, "class","value", c(mean.propCore.:mean.propNeither.))
prope_long = arrange(prope_long, desc(class))
prope_long$system = as.factor(prope_long$system)

##################################################################
# barplot of % transients versus community size at diff thresholds
datasetIDs = dataformattingtable$dataset_ID[dataformattingtable$format_flag == 1]

### Have to cut out stuff that have mean abundance NA
datasetIDs = datasetIDs[!datasetIDs %in% c(1, 67,270,271,317,319,325)]

percTransSummaries = c()
for (d in datasetIDs) {
  percTransSumm = summaryTransFun(d)
  
  percTransSummaries = rbind(percTransSummaries, percTransSumm)
  print(d)
}
percTransSummaries = percTransSummaries[, c("datasetID","site","system","taxa","propCore33", "propTrans33", "propTrans25", "propTrans10")]

#rbind threshold dataset with BBS thresholds
bbs_focal_occs_pctTrans = read.csv("data/BBS/bbs_focal_occs_pctTrans.csv", header = TRUE)
bbs_focal_occs_pctTrans$site = as.factor(bbs_focal_occs_pctTrans$site)
percTransSummaries$propCore33 = NULL
percTransSummaries_w_bbs = rbind(percTransSummaries, bbs_focal_occs_pctTrans)
write.csv(percTransSummaries_w_bbs, "output/tabular_data/alt_trans_thresholds.csv", row.names = F)

CT_plot=merge(percTransSummaries_w_bbs, taxcolors, by="taxa")
CT_long = gather(CT_plot, "level_trans","pTrans", propTrans33:propTrans10)

ttrans = CT_plot %>%
  dplyr::group_by(taxa) %>%
  dplyr::summarize(mean(propTrans33)) 

propCT_long$abbrev = propCT_long$taxa
propCT_long$abbrev = gsub("Benthos", 'Be', propCT_long$abbrev)
propCT_long$abbrev = gsub("Bird", 'Bi', propCT_long$abbrev)
propCT_long$abbrev = gsub("Fish", 'F', propCT_long$abbrev)
propCT_long$abbrev = gsub("Invertebrate", 'I', propCT_long$abbrev)
propCT_long$abbrev = gsub("Mammal", 'M', propCT_long$abbrev)
propCT_long$abbrev = gsub("Plankton", 'Pn', propCT_long$abbrev)
propCT_long$abbrev = gsub("Plant", 'Pt', propCT_long$abbrev)
propCT_long$abbrev = factor(propCT_long$abbrev,
                            levels = c('Be','I','F','Pn','Pt','M','Bi'),ordered = TRUE)

colscale = c("light gray","dark gray", "black")
m = ggplot(data=propCT_long, aes(factor(abbrev), y=value, fill=factor(class))) + geom_bar(stat = "identity")  + xlab("") + ylab("Proportion of Species") + scale_fill_manual(labels = c("Core", "Intermediate", "Transient"),values = colscale)+theme(axis.ticks.x=element_blank(),axis.text.x=element_text(size=6),axis.text.y=element_text(size=20),axis.title.y=element_text(size=24,angle=90,vjust = 4),axis.line.x = element_blank(),axis.line.y = element_blank())+ theme(legend.text=element_text(size=24),legend.key.size = unit(2, 'lines'))+theme(legend.position="right", legend.key.width=unit(1, "lines"))+ guides(fill = guide_legend(keywidth = 3, keyheight = 2,title="", reverse=TRUE))+ coord_fixed(ratio = 4)
# ggsave(file="C:/Git/core-transient/output/plots/3a.pdf", height = 10, width = 15)

prope_long$system = factor(prope_long$system,
                            levels = c('Freshwater','Marine','Terrestrial'),ordered = TRUE)


# colscaleb = c("tan","brown", "dark green")
e = ggplot(data=prope_long, aes(factor(system), y=value, fill=factor(class))) + 
  geom_bar(stat = "identity")  + xlab("") + ylab("")+ scale_fill_manual(labels = c("Core", "Intermediate", "Transient"), values = colscale)+
  theme(axis.ticks.x=element_blank(),axis.text.x=element_text(size=4),axis.text.y=element_text(size=20),
        axis.title.x=element_text(size=24),axis.title.y=element_text(size=24,angle=90,vjust = 2.5),
        axis.line.x = element_blank(),axis.line.y = element_blank())+ theme(legend.text=element_text(size=18),
        legend.key.size = unit(2, 'lines'))+theme(legend.position="top", legend.justification=c(0, 1), 
        legend.key.width=unit(1, "lines"))+ guides(fill = guide_legend(keywidth = 3, keyheight = 1,title="", 
                                                                       reverse=TRUE))+ coord_fixed(ratio = 4)


# make a gridded plot
get_legend<-function(myggplot){
  tmp <- ggplot_gtable(ggplot_build(myggplot))
  leg <- which(sapply(tmp$grobs, function(x) x$name) == "guide-box")
  legend <- tmp$grobs[[leg]]
  return(legend)
}
legend <- get_legend(m + theme(legend.position="right"))
prow <- plot_grid( m + theme(legend.position="none"),
                   e + theme(legend.position="none"),
                   align = 'vh',
                   labels = c("A", "B"),
                   label_size = 26,
                   vjust = 5,
                   hjust = -4,
                   nrow = 1
)
p2 = plot_grid(prow,legend, rel_widths = c(3, 0.7)) 
p2
ggsave(file="output/plots/3a_3b.pdf", height = 10, width = 15,p2)

#### barplot of percent transients by taxa --- Figure S3
CT_long$taxa = as.factor(CT_long$taxa)
CT_long$abbrev = CT_long$taxa
CT_long$abbrev = gsub("Benthos", 'Be', CT_long$abbrev)
CT_long$abbrev = gsub("Bird", 'Bi', CT_long$abbrev)
CT_long$abbrev = gsub("Fish", 'F', CT_long$abbrev)
CT_long$abbrev = gsub("Invertebrate", 'I', CT_long$abbrev)
CT_long$abbrev = gsub("Mammal", 'M', CT_long$abbrev)
CT_long$abbrev = gsub("Plankton", 'Pn', CT_long$abbrev)
CT_long$abbrev = gsub("Plant", 'Pt', CT_long$abbrev)
CT_long$abbrev = factor(CT_long$abbrev,
                        levels = c('Be','I','F','Pn','Pt','M','Bi'),ordered = TRUE)


p <- ggplot(CT_long, aes(x = reorder(abbrev, -pTrans), y = pTrans))+theme_classic()

cols <- (CT_long$color)
cols=c("#ece7f2","#9ecae1", "#225ea8")


p = p+geom_boxplot(width=0.8,position=position_dodge(width=0.8),aes(x=factor(abbrev), y=pTrans, fill=level_trans))+ 
  scale_colour_manual(breaks = CT_long$level_trans,
                      values = taxcolors$color)  + xlab("Taxa") + ylab("Proportion of Species")+
  scale_fill_manual(labels = c("10%", "25%", "33%"),
                    values = cols)+theme(axis.ticks.x=element_blank(),axis.text.x=element_text(size=20),axis.text.y=element_text(size=20),axis.title.x=element_text(size=24),axis.title.y=element_text(size=24,angle=90,vjust = 2))+guides(fill=guide_legend(title="",keywidth = 2, keyheight = 1)) + theme(legend.text=element_text(size=24),legend.key.size = unit(2, 'lines'), legend.title=element_text(size=24))+theme(legend.position="top", legend.justification=c(0, 1), legend.key.width=unit(1, "lines"))+ coord_fixed(ratio = 4)
ggsave(file="C:/Git/core-transient/output/plots/supp_3.pdf", height = 10, width = 15,p)

---
output:
  word_document: default
  pdf_document: default
  html_document: default
---
# Script and session info
Script name: WGCNA-colon.Rmd

Purpose of script: Using gene co-expression network to functionally analyse mRNA and miRNA expression trends in colon cancer progression 
Author: Aishwarya Iyer

Date Created: 17-10-2020

## Session info:
R version 3.10 
Platform: x86_64-w64-mingw32/x64 (64-bit)
Running under: Windows 10 x64 

# Set up environment
```{r}
#clear workspace and set string as factors to false
rm(list=ls())
options(stringsAsFactors = F)

```

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = TRUE)
```

# Install required packages
```{r,echo=FALSE}
#BiocManager::install("WGCNA")
##install devtools
#install.packages("devtools") #if needed
#install PANEV
#library("devtools")
#install_github("vpalombo/PANEV")
#BiocManager::install("clusterProfiler")
library(WGCNA)
library(rstudioapi)
library(dplyr)
library(biomaRt)
library(clusterProfiler)
library(PANEV)
```


```{r}
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
```

# read data and combine them to input file for WGCNA
```{r}
colon_stage_1<-read.table("stage1_rna_matrix.txt", sep ="\t", header=TRUE,row.names = 1)
colon_stage_2<-read.table("stage2_rna_matrix.txt", sep ="\t", header=TRUE,row.names = 1)
colon_stage_3<-read.table("stage3_rna_matrix.txt", sep ="\t", header=TRUE,row.names = 1)
colon_stage_4<-read.table("stage4_rna_matrix.txt", sep ="\t", header=TRUE,row.names = 1)





#merge the for the four colon cancer stages
#merging stage 1 and 2 data
commongenes_1_2 = intersect (rownames(colon_stage_1),rownames(colon_stage_2))
new_colon_stage_1 = colon_stage_1[commongenes_1_2,]
new_colon_stage_2 = colon_stage_2[commongenes_1_2,] 
combined_stage1_2<-as.data.frame(cbind(new_colon_stage_1,new_colon_stage_2))

#merge stage 1,2, and 3
common_genes_1_2_3=intersect (rownames(combined_stage1_2),rownames(colon_stage_3))
new_colon_stage_1_2 = combined_stage1_2[common_genes_1_2_3,]
new_colon_stage_3 = colon_stage_3[common_genes_1_2_3,] 
combined_stage1_2_3<-as.data.frame(cbind(new_colon_stage_1_2,new_colon_stage_3))

#merge stage 1,2,3 and 4
common_genes_all=intersect (rownames(combined_stage1_2_3),rownames(colon_stage_4))
new_colon_stage_1_2_3 = combined_stage1_2_3[common_genes_all,]
new_colon_stage_4 = colon_stage_4[common_genes_all,] 
combined_stage_all<-as.data.frame(cbind(new_colon_stage_1_2_3,new_colon_stage_4))

#change column names in the merged dataframe
columnames_1<-rep(c("stage_1"), each = c(31))
columnames_2<-rep(c("stage_2"), each = c(82))
columnames_3<-rep(c("stage_3"), each = c(59))
columnames_4<-rep(c("stage_4"), each = c(23))
column_names_1_2<-c(columnames_1,columnames_2,columnames_3,columnames_4)
colnames(combined_stage_all)<-column_names_1_2
```

```{r}
##annotate the genes in the dataframe with ensemble gene ids
#BiocManager::install("biomaRt")#install the package

require(biomaRt)
ensembl<-useMart("ensembl",dataset ="hsapiens_gene_ensembl")

annotate<-getBM(attributes=c('hgnc_symbol','entrezgene_id'),
                filter='hgnc_symbol',
                values=rownames(combined_stage_all),
                mart=ensembl)
                
#matching the genes with dataframe to check for number of genes not annotated                 
probes2annot = match(rownames(combined_stage_all), annotate$hgnc_symbol)

# The following is the number or probes without annotation:
sum(is.na(probes2annot))
#aroubnd 3000 genes are not annotated .

#Add ensemble gene id to the merged dataframe
rownames(annotate) = make.names(annotate$hgnc_symbol, unique=TRUE) #add the rownames to annotate dataframe
genes_match<-intersect(rownames(annotate),rownames(combined_stage_all))
combined_stage_all_1<-combined_stage_all[genes_match,]
gene_id<-data.frame(annotate[genes_match,])
combined_stage_all_1$gene_id<-gene_id[,2] #add gene id to teh merged dataframe

rownames(combined_stage_all_1)<-make.names(combined_stage_all_1$gene_id, unique=TRUE)#make them as rownames
combined_stage_all_1$gene_id<-NULL
```

# check if there are samples with missing data
```{r}
gsg = goodSamplesGenes(combined_stage_all_1, verbose = 3);
gsg$allOK

# remove rows with all low expression
combined.filtered <- combined_stage_all_1[rowSums(combined_stage_all_1) > 0.5, , drop=TRUE]
combined.filtered <- as.data.frame(t(as.matrix(combined.filtered)))
```

```{r}
sampleTree = hclust(dist(combined.filtered), method = "ward.D2");

# Plot the sample tree: Open a graphic output window of size 12 by 9 inches
# The user should change the dimensions if the window is too large or too small.
sizeGrWindow(12,9)
#pdf(file = "Plots/sampleClustering.pdf", width = 12, height = 9);
par(cex = 0.6);
par(mar = c(0,4,2,0))
plot(sampleTree, main = "Sample clustering to detect outliers", hang=-1,sub="", xlab="", cex.lab = 1.5, 
     cex.axis = 1.5, cex.main = 2)


```

```{r}
#create a trait dataframe using the colonm cancer stage as values from 1,2,3 and 4.
columnames_1<-rep(c(1), each = c(31))
columnames_2<-rep(c(2), each = c(82))
columnames_3<-rep(c(3), each = c(59))
columnames_4<-rep(c(4), each = c(23))
column_names_1_2<-c(columnames_1,columnames_2,columnames_3,columnames_4)
trait_data<-as.data.frame(rownames(combined.filtered))
trait_data$stage<-as.numeric(column_names_1_2)
trait_data$stage_1<-trait_data$stage #add an extra stage column will be further used to visulaize module-trait relationship
colnames(trait_data)<-c("samples","stage","stage_1")#add columnnames to trait data

#add the rownames to trait data 
rownames(trait_data) = trait_data$samples;
trait_data$samples<-NULL

collectGarbage();
```

#merge together the filtered table with the information from the Giannakis dataset
```{r}
# Re-cluster samples
sampleTree2 = hclust(dist(combined.filtered), method = "ward.D2")
# Convert traits to a color representation: white means low, red means high, grey means missing entry
traitColors = numbers2colors(trait_data, signed = FALSE);
sizeGrWindow(12,12)

# Plot the sample dendrogram and the colors underneath.
plotDendroAndColors(sampleTree2, traitColors,
                    groupLabels = names(trait_data), 
                    main = "Sample dendrogram and trait heatmap",
                    addGuide = TRUE)
##stage 2.14 and stage 4.4 outliers 

```

```{r}
#remving outliers
rows_removed<-c("stage_2.14","stage_4.4")
 combined.filtered = combined.filtered[!row.names(combined.filtered)%in%rows_removed, ]
 trait_data<-as.data.frame(t(trait_data))
 trait_data$stage_2.14<-NULL
 trait_data$stage_4.4<-NULL
   
  trait_data<-as.data.frame(t(trait_data))
 
 # Re-cluster samples
sampleTree2 = hclust(dist(combined.filtered), method = "ward.D2")
# Convert traits to a color representation: white means low, red means high, grey means missing entry
traitColors = numbers2colors(trait_data$stage, signed = FALSE);
```

```{r,dev='png'}

sizeGrWindow(12,12)

# Plot the sample dendrogram and the colors underneath.
plotDendroAndColors(sampleTree2, traitColors,
                    groupLabels = "cancer stage", 
                    main = "Sample dendrogram and trait heatmap",
                    addGuide = TRUE,cex.colorLabels = 1.2,cex.main=1.5)



```

```{r}
save(combined.filtered, trait_data, file = "WGCNA-input.RData")
```





#########################################
Network construction and module detection
#########################################

```{r}
# Allow multi-threading within WGCNA. This helps speed up certain calculations.
# At present this call is necessary for the code to work.
# Any error here may be ignored but you may want to update WGCNA if you see one.
# Caution: skip this line if you run RStudio or other third-party R environments. 
# See note above.
enableWGCNAThreads()
# Load the data saved in the first part
lnames = load(file = "WGCNA-input.RData");
#The variable lnames contains the names of loaded variables.
lnames
```

```{r}
# Choose a set of soft-thresholding powers

powers = c(c(1:10), seq(from = 12, to=20, by=2))
# Call the network topology analysis function
sft = pickSoftThreshold(combined.filtered, powerVector = powers, verbose = 5,networkType = "unsigned")#using unsigned option
# Plot the results:
sizeGrWindow(9, 5)
par(mfrow = c(1,2));
cex1 = 0.9;
# Scale-free topology fit index as a function of the soft-thresholding power
plot(sft$fitIndices[,1], -sign(sft$fitIndices[,3])*sft$fitIndices[,2],
     xlab="Soft Threshold (power)",ylab="Scale Free Topology Model Fit,unsigned R^2",type="n",
     main = paste("Scale independence"));
text(sft$fitIndices[,1], -sign(sft$fitIndices[,3])*sft$fitIndices[,2],
     labels=powers,cex=cex1,col="red");
# this line corresponds to using an R^2 cut-off of h
abline(h=0.90,col="red")
# Mean connectivity as a function of the soft-thresholding power
plot(sft$fitIndices[,1], sft$fitIndices[,5],
     xlab="Soft Threshold (power)",ylab="Mean Connectivity", type="n",
     main = paste("Mean connectivity"))
text(sft$fitIndices[,1], sft$fitIndices[,5], labels=powers, cex=cex1,col="red")
#choosing power 5 to get a sclae free network
```

```{r}
#get the modules from the gene expression dataframe
net = blockwiseModules(combined.filtered, power = 5,corType = "pearson",
                       TOMType = "unsigned", minModuleSize = 30,
                       reassignThreshold = 0, mergeCutHeight = 0.25,
                       numericLabels = TRUE, pamRespectsDendro = FALSE,
                       saveTOMs = TRUE,
                       saveTOMFileBase = "expTOM", 
                       verbose = 3)
```


```{r}
# open a graphics window
sizeGrWindow(15, 9)
# Convert labels to colors for plotting
mergedColors = labels2colors(net$colors)
# Plot the dendrogram and the module colors underneath
plotDendroAndColors(net$dendrograms[[1]], mergedColors[net$blockGenes[[1]]],
                    "Module colors",
                    dendroLabels = FALSE, hang = 0.03,
                    addGuide = TRUE, guideHang = 0.05)
```

```{r}
# open a graphics window
sizeGrWindow(15, 9)
moduleLabelsAutomatic = net$colors
# Convert labels to colors for plotting
moduleColorsAutomatic = labels2colors(moduleLabelsAutomatic)

# A data frame with module eigengenes can be obtained as follows
MEsAutomatic = net$MEs

# this is the body weight
stage = as.data.frame(trait_data$stage)
names(stage) = "stage"
# Next use this trait to define a gene significance variable
GS.stage = as.numeric(cor(combined.filtered, stage, use = "p"))
# This translates the numeric values into colors
GS.stageColor = numbers2colors(GS.stage, signed = T)
blocknumber = 1
datColors = data.frame(moduleColorsAutomatic, GS.stageColor)[net$blockGenes[[blocknumber]], 
    ]
```

```{r}
# Plot the dendrogram and the module colors underneath
plotDendroAndColors(net$dendrograms[[blocknumber]], colors = datColors, groupLabels = c("Module colors", 
    "cancer stage"), dendroLabels = FALSE, hang = 0.03, addGuide = TRUE, guideHang = 0.05,cex.colorLabels = 1.2)
```

```{r}
moduleLabels = net$colors
moduleColors = labels2colors(net$colors)
table(moduleColors)
MEs = net$MEs;
geneTree = net$dendrograms[[1]];
save(MEs, moduleLabels, moduleColors, geneTree, 
     file = "network-reconstruction.RData")
```



##########################################
Relate modules to external clinical traits
##########################################
```{r}
# Define numbers of genes and samples
nGenes = ncol(combined.filtered);
nSamples = nrow(combined.filtered);
# Recalculate MEs with color labels
MEs0 = moduleEigengenes(combined.filtered, moduleColors)$eigengenes
MEs = orderMEs(MEs0)
moduleTraitCor = cor(MEs, trait_data, use = "p");
moduleTraitPvalue = corPvalueStudent(moduleTraitCor, nSamples);


```

```{r}
# calculate the module membership values (aka. module eigengene based
# connectivity kME):
datKME = signedKME(combined.filtered, MEs,outputColumnName = "kME")#to calculate the correlation of the modules with the trait (colon cancer stage)
```

```{r}
# open a graphics window
sizeGrWindow(100,100)
colorOfColumn = substring(names(datKME), 4)
par(mfrow = c(2,2))
selectModules = c("green","darkred","red","brown"
                  )
par(mfrow = c(2, length(selectModules)/2))
for (module in selectModules) {
    column = match(module, colorOfColumn)
    restModule = moduleColors == module
    verboseScatterplot(datKME[restModule, column], GS.stage[restModule], xlab = paste("Module_membership ", 
        module, "module"), ylab = "GS.stage", main = paste("unsignedkME.", module,".vs GS" 
        ),col=module)
}
```

```{r}
#plotting the module with highest significant correlation
# open a graphics window
sizeGrWindow(100,100)
colorOfColumn = substring(names(datKME), 4)

selectModules = c("green"
                  )

for (module in selectModules) {
    column = match(module, colorOfColumn)
    restModule = moduleColors == module
    verboseScatterplot(datKME[restModule, column], GS.stage[restModule], xlab = paste(module,"module membership "
        ), ylab = "cancer stage", main = paste("Correlation of green module with colon cancer stage" 
        ),col=module,abline = TRUE,pch=16,cex.lab = 1.5)
}
```

```{r}
# calculate the module membership values (aka. module eigengene based
# connectivity kME):
datKME = signedKME(combined.filtered, MEs,outputColumnName = "kME")
# open a graphics window
sizeGrWindow(100,100)
colorOfColumn = substring(names(datKME), 4)
par(mfrow = c(2,2))
selectModules = c("salmon","blue","darkorange","brown"
                  )
par(mfrow = c(2, length(selectModules)/2))
for (module in selectModules) {
    column = match(module, colorOfColumn)
    restModule = moduleColors == module
    verboseScatterplot(datKME[restModule, column], GS.stage[restModule], xlab = paste("Module_membership ", 
        module, "module"), ylab = "GS.stage", main = paste("unsignedkME.", module,".vs GS" 
        ),col=module)
}
```

```{r}
# Load the expression and trait data saved in the first part
lnames = load(file = "WGCNA-input.RData");
#The variable lnames contains the names of loaded variables.
lnames
# Load network data saved in the second part.
lnames = load(file = "network-reconstruction.RData");
lnames
```


```{r}
# Define variable time containing the stage column of trait data
stage = as.data.frame(trait_data$stage);
names(stage) = "stage"
# names (colors) of the modules
modNames = substring(names(MEs), 3)

geneModuleMembership = as.data.frame(cor(combined.filtered, MEs, use = "p"));
MMPvalue = as.data.frame(corPvalueStudent(as.matrix(geneModuleMembership), nSamples));

names(geneModuleMembership) = paste("MM", modNames, sep="");
names(MMPvalue) = paste("p.MM", modNames, sep="");

geneTraitSignificance = as.data.frame(cor(combined.filtered, stage, use = "p"));
GSPvalue = as.data.frame(corPvalueStudent(as.matrix(geneTraitSignificance), nSamples));

names(geneTraitSignificance) = paste("GS.", names(stage), sep="");
names(GSPvalue) = paste("p.GS.", names(stage), sep="");
```


```{r}


#remving the 'x' from the column names of expression dataset 
for ( col in 1:ncol(combined.filtered)){
  colnames(combined.filtered)[col] <-  sub("X", "", colnames(combined.filtered)[col])
}

```


```{r}
# Create the starting data frame containing gene id , module they are present in, significance and correlation for each gene
geneInfo0 = data.frame(Gene.Symbol = colnames(combined.filtered),
                      moduleColor = moduleColors,
                      geneTraitSignificance,
                      GSPvalue)

##selecting genes in green module
green_module_genes<-subset(geneInfo0,moduleColor=="green")

```


```{r}
#performing over representation analysis for pathways using KEGG 
#creating dataframe with ensemble id, entrez id and gene symbols.
gene.df <- bitr(ensemble_gene_list$V1, fromType = "ENSEMBL",
        toType = c("ENTREZID", "SYMBOL"),
        OrgDb = org.Hs.eg.db)

#over representation analysis using KEGG 
over_rep_pathways <- data.frame(enrichKEGG(gene= gene.df$ENTREZID,
                                organism     = 'hsa',
                                pvalueCutoff = 0.05))
#print the result
head(over_rep_pathways)
```



###################################
Network visualization 
###################################

```{r}

# Create a list of all the available organisms for biomaRt annotation
list <- panev.biomartSpecies(string = NULL)
# Look for a specific organism matching a search string for biomaRt annotation
list <- panev.biomartSpecies(string = "Human")
#select the correct organism fo interest
biomart.species.bos <- as.character(list[1,1])
# Prepare the dataset for panev.network function converting gene name from ensembl to entrez id
ensemble_id<-getBM(attributes=c('ensembl_gene_id','entrezgene_id'),
                filter='entrezgene_id',
                values=green_module_genes$Gene.Symbol,
                mart=ensembl)
#create dataframe of ensemble gene id 
ensemble_gene_list<-data.frame(ensemble_id$ensembl_gene_id)
#assign columnnames 
colnames(ensemble_gene_list)<-c("ensemble_id")
#export the ensemble gene id as a text file
write.table(ensemble_gene_list,"ensemble gene list.txt",row.names = F,quote = F)

#ensemble_gene_list<-read.table("ensemble gene list.txt",header = F,stringsAsFactors = F)
# Preparation of the dataset for panev.network function, converting gene name from entrez to ensembl id
genelist.converted <- panev.dataPreparation(in.file = "ensemble gene list.txt", 
                                          gene_id = "ensembl", 
                                          biomart.species = biomart.species.bos)
#export the dataframe containing entrex id, ensemble gen id and gene symbols 
write.table(genelist.converted,"data.txt",row.names = F,quote = F)
#get the pathway list from KEGG
list <- panev.pathList(string = NULL)#path:map04146 path:map00730 path:map00740 path:map00750 path:map01524 path:map02010 path:map04514
#Idenify the pathways of interest ( were selected using information from functional annoation clustering DAVID and ORA for pathways)
FL.gene <- c("path:map04146", "path:map00730", "path:map00740", "path:map00750","path:map01524","path:map02010","path:map04514")
write.table(list,"list.txt")

# Create a list of all available organisms in KEGG
list <- panev.speciesCode(string = "human")
#select appropriate organism
KEGG.species.bos <- as.character(list[1,2])
#Perform PANEV
panev.network(in.file = "data.txt", 
              out.file = "example", 
              species = KEGG.species.bos, 
              FL = FL.gene, 
              levels = 2)
#Export the files to folder PANEV_RESULTS_example. The HTML file can be used to visulaize the network
genes.1L <- read.table("C:\\Users\\HP\\Desktop\\Network Biology\\project\\Colon\\MicroRNA-Gene-Network-Colon\\Data\\PANEV_RESULTS_example\\1Lgenes.txt", header = TRUE)
```


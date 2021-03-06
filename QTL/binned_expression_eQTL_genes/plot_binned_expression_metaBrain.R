library("optparse")
library(ggplot2)
library(ggpubr)
library(gridExtra)

# Get command line arguments 
option_list = list(
  make_option(c("-c", "--cisQTLs"), type="character",
              help="eQTLProbesFDR0.05-ProbeLevel.txt.gz of cis-eQTLs", metavar="character"),
  make_option(c("-t", "--transQTLs"), type="character",
              help="eQTLProbesFDR0.05-ProbeLevel.txt.gz of trans-eQTLs", metavar="character"),
  make_option(c("-e", "--expression"), type="character",
              help="File with mean expression per gene", metavar="character"),
  make_option(c("-p", "--proteinCodingGenes"), type="character",
              help="File with protein coding genes", metavar="character")
  
); 

opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);

opt <- list()
#opt$cisQTLs <- "/Users/NPK/UMCG/projects/biogen/cohorts/joined_analysis/binned_expression_eQTL_genes/eQTLProbesFDR0.05-ProbeLevel.CIS.txt.gz"
#opt$transQTLs <- "/Users/NPK/UMCG/projects/biogen/cohorts/joined_analysis/binned_expression_eQTL_genes/eQTLProbesFDR0.05-ProbeLevel.TRANS.txt.gz"
#opt$expression <- "/Users/NPK/UMCG/projects/biogen/cohorts/joined_analysis/binned_expression_eQTL_genes/MERGED_RNA_MATRIX.SampleSelection.ProbesWithZeroVarianceRemoved.QuantileNormalized.Log2Transformed.MEAN_AND_SD.txt"
#opt$proteinCodingGenes <- "/Users/NPK/UMCG/projects/biogen/cohorts/joined_analysis/binned_expression_eQTL_genes/protein_coding_genes_ensembl84.txt"

##### read in data ####
cis_qtl <- read.table(gzfile(opt$cisQTLs), header=T, sep='\t')
trans_qtl <- read.table(gzfile(opt$transQTLs), header=T, sep='\t')
protein_coding_genes <- read.table(opt$proteinCodingGenes, sep='\t', header=T)

# make sure all are FDR < 0.05
cis_qtl <- cis_qtl[cis_qtl$FDR < 0.05,]
trans_qtl <- trans_qtl[trans_qtl$FDR < 0.05,]

expression <- read.table(opt$expression, header=T, sep='\t', row.names=1)

# genes still have version numbers, remove
rownames(expression) <- sapply(strsplit(rownames(expression),"\\."), `[`, 1)
cis_qtl$ProbeName <- sapply(strsplit(as.character(cis_qtl$ProbeName),"\\."), `[`, 1)
trans_qtl$ProbeName <- sapply(strsplit(as.character(trans_qtl$ProbeName),"\\."), `[`, 1)

# select only protein coding genes
expression <- expression[rownames(expression) %in% protein_coding_genes$Ensembl.Gene.ID,]
cis_qtl <- cis_qtl[cis_qtl$ProbeName %in% protein_coding_genes$Ensembl.Gene.ID,]
trans_qtl <- trans_qtl[trans_qtl$ProbeName %in% protein_coding_genes$Ensembl.Gene.ID,]
#####

##### per expression bin calculate the proportion of cis/trans eQTLs #####
expression$expression_bin <- cut_number(expression$mean_expression, 10)

gene_per_bin <- data.frame()
gene_lengths_per_bin <- data.frame()
for(bin in sort(unique(expression$expression_bin))){
  expression_current_bin <- expression[expression$expression_bin==bin,]
  genes_current_bin <- rownames(expression_current_bin)
  n_genes <- length(genes_current_bin)
  n_cis_QTL <- sum(genes_current_bin %in% cis_qtl$ProbeName)
  n_trans_QTL <- sum(genes_current_bin %in% trans_qtl$ProbeName)
  
  
  mean_sd_cis <- round(mean(expression_current_bin[rownames(expression_current_bin) %in% cis_qtl$ProbeName,]$SD),2)
  mean_sd_not_cis <- round(mean(expression_current_bin[!rownames(expression_current_bin) %in% cis_qtl$ProbeName,]$SD),2)
  
  gene_lengths <- protein_coding_genes[match(rownames(expression_current_bin), protein_coding_genes$Ensembl.Gene.ID),]
  is_cis_qtl <- gene_lengths$Ensembl.Gene.ID %in% cis_qtl$ProbeName
  is_trans_qtl <- gene_lengths$Ensembl.Gene.ID %in% trans_qtl$ProbeName
  
  df <- data.frame('bin'=bin, 'length'=gene_lengths$Transcript.length..including.UTRs.and.CDS.,
                   'is_cis_qtl'=is_cis_qtl,'is_trans_qtl'=is_trans_qtl,'gene'=gene_lengths$Ensembl.Gene.ID,
                   'expression'=expression_current_bin[gene_lengths$Ensembl.Gene.ID,]$mean_expression,
                   'sd'=expression_current_bin[gene_lengths$Ensembl.Gene.ID,]$mean_expression)
  gene_lengths_per_bin <- rbind(gene_lengths_per_bin, df)
  
  df <- data.frame('n_genes'=c((n_cis_QTL/n_genes)*100, 
                               (n_trans_QTL/n_genes)*100, 
                               ((n_genes-n_cis_QTL)/n_genes)*100, 
                               ((n_genes-n_trans_QTL)/n_genes)*100),
                   'bin'=c(bin, bin, bin, bin),
                   'qtl_type'=c('cis','trans','cis','trans'),
                   'genes_are_QTL'=c('yes','yes','no','no'))
  gene_per_bin <- rbind(gene_per_bin, df)
}
#####
 

#### make the histogram ####
ggplot(gene_per_bin, aes(bin, n_genes, fill=genes_are_QTL))+
  geom_bar(stat='identity')+
  scale_fill_manual(values=c('grey95','lightblue'))+
  theme_pubr(base_size=18)+ 
  guides(fill=FALSE)+
  facet_wrap(~qtl_type)+ 
  xlab('Expression levels')+
  ylab('Proprotion QTLs')+
  scale_y_continuous(breaks=c(0,10,20,30,40,50,60,70,80,90,100),
                     labels=c('0%','10%','20%','30%','40%','50%','60%','70%','80%','90%','100%'))+
  theme(axis.text= element_text(colour='grey70'))+
  scale_x_discrete(breaks = c('[0.00778,0.774]','(10.9,19.3]'),
                 labels=c('low','high'))
ggsave('figures/proortion_of_QTL_per_bin_proteinCoding_only.png',width=8, height=5)  


ggplot(gene_per_bin[gene_per_bin$qtl_type=='cis',], aes(bin, n_genes, fill=genes_are_QTL))+
  geom_bar(stat='identity')+
  scale_fill_manual(values=c('grey95','lightblue'))+
  theme_pubr(base_size=18)+ 
  guides(fill=FALSE)+
  xlab('Average brain gene expression')+
  ylab('Proportion of genes showing cis-eQTL effect')+
  scale_y_continuous(breaks=c(0,10,20,30,40,50,60,70,80,90,100),
                     labels=c('0%','10%','20%','30%','40%','50%','60%','70%','80%','90%','100%'))+
  theme(axis.text= element_text(colour='grey70'))+
  scale_x_discrete(breaks = c('[0.00778,0.774]','(10.9,19.3]'),
                   labels=c('low','high'))
ggsave('figures/proportion_of_QTL_per_bin_proteinCoding_only_cis.png',width=8, height=5)  

####



#### per bin plot the length of the genes for the QTL genes and non-QTL genes ####
p1 <- ggplot(gene_lengths_per_bin, aes(log(length), fill=is_cis_qtl))+
  geom_histogram(position="identity", alpha=0.5)+
  facet_wrap(~bin, ncol=2)+
  theme_pubr(base_size=18)+
  scale_fill_manual(values=c('grey70','blue'))+
  labs(fill="is cis QTL")
ggsave('figures/length_per_expression_bin_cis.pdf',width=8, height=12)  


p2 <- ggplot(gene_lengths_per_bin, aes(log(length), fill=is_trans_qtl))+
  geom_histogram(position="identity", alpha=0.5)+
  facet_wrap(~bin, ncol=2)+
  theme_pubr(base_size=18)+
  scale_fill_manual(values=c('grey70','blue'))+
  labs(fill="is trans QTL")
ggsave('figures/length_per_expression_bin_trans.pdf',width=8, height=12)  

pdf('figures/length_per_expression_bin.pdf',width=12, height=12)  
grid.arrange(p1, p2, nrow = 1)
dev.off()
####


#### writing genes from highest bin for GO analysis ####
highest_bin <- gene_lengths_per_bin[gene_lengths_per_bin$bin == "(10.9,19.3]",]
write.table(as.character(highest_bin[highest_bin$is_cis_qtl,]$gene), 'cis_qtl_genes_highest_bin.txt',
            quote=F, row.names=F)
write.table(as.character(highest_bin[!highest_bin$is_cis_qtl,]$gene), 'not_cis_qtl_genes_highest_bin.txt',
            quote=F, row.names=F)
####

#### plot sd per bin for cis vs non cis ####
p1 <- ggplot(gene_lengths_per_bin, aes(sd, fill=is_cis_qtl))+
  geom_histogram(position='identity')+
  theme_pubr(base_size=18)+ 
  scale_fill_manual(values=c('grey95','lightblue'))+
  facet_wrap(~bin, ncol=2,scale='free_x')

p2 <- ggplot(gene_lengths_per_bin, aes(sd, fill=is_trans_qtl))+
  geom_histogram(position='identity')+
  theme_pubr(base_size=18)+ 
  scale_fill_manual(values=c('grey95','lightblue'))+
  facet_wrap(~bin, ncol=2,scale='free_x')
pdf('figures/sd_per_expression_bin.pdf',width=12, height=12)  
grid.arrange(p1, p2, nrow = 1)
dev.off()
####

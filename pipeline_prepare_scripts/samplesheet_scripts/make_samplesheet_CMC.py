
# loop through all subdirs to find all fastq files
import sys
import os.path
import glob
import os
import re


if len(sys.argv) != 2:
    raise RuntimeError('Not correct number of arguments')

individual_per_sample = {}
samples_per_batch = {}
batch_count = {}

# TODO: change hard path
with open(sys.argv[1]) as input_file:
    header = input_file.readline().split('\t')
    for line in input_file:
        line = line.strip().replace('"','').split('\t')
        aligned_bam = line[4]
        if not aligned_bam.endswith('.accepted_hits.sort.coord.bam'):
            continue
        sample_id = line[-1]
        individual_id = line[-2]
        if sample_id in individual_per_sample:
            raise RuntimeError('Sample ID in multiple times')
        individual_per_sample[sample_id] = individual_id

        unaligned_bam = aligned_bam.replace('BamAlignedReadData','BamUnmappedReadData').replace('accepted_hits.sort.coord.bam','unmapped.bam')

        fastq_path = '/groups/umcg-biogen/tmp03/input/CMC/pipelines/results/fastq/'+sample_id+'_R1.fq.gz'
        batch = re.search('(.*?)_\d+', sample_id).group(1)
        if batch not in batch_count:
            batch_count[batch] = 0
        batch_count[batch] += 1
        if batch_count[batch] > 25 and batch_count[batch] < 50:
            batch = batch+'_batch2'
        elif batch_count[batch] >= 50 and batch_count[batch] < 75:
            batch = batch+'_batch3'
        elif batch_count[batch] >= 75 and batch_count[batch] < 100:
            batch = batch+'_batch4'
        elif batch_count[batch] >= 100:
            batch = batch+'_batch5'
        print(batch)
        if batch not in samples_per_batch:
            samples_per_batch[batch] = []
        samples_per_batch[batch].append([fastq_path, sample_id, aligned_bam, unaligned_bam])

for batch in samples_per_batch:
    print(batch)
    with open('Public_RNA-seq_QC/samplesheets/samplesheet_CMC_RNA.'+batch+'.txt','w') as out:
        out.write('internalId,project,sampleName,reads1FqGz,reads2FqGz,alignedBam,unalignedBam\n')
        for data in samples_per_batch[batch]:
            print(data[1], individual_per_sample[data[1]])
            out.write('specimenID.'+data[1]+',CMC,'+'individualID.'+individual_per_sample[data[1]]+','+data[0]+','+data[0].replace('R1','R2')+',')
            out.write('/groups/umcg-biogen/tmp03/input/CMC/RNAseq/DorsolateralPrefrontalCortex/Raw/BamAlignedReadData/'+data[2])
            out.write(',/groups/umcg-biogen/tmp03/input/CMC/RNAseq/DorsolateralPrefrontalCortex/Raw/BamUnmappedReadData/'+data[3]+'\n')
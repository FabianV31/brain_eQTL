#!/usr/bin/env bash

# Download and make quantification pipeline
# This script clones the Molgenis Compute pipeline for alignin FastQ files and
# modifies the protocols and parameter files for analysis of Brain eQTL data.
# Makes samplesheet dependent parameter files.

# NOTE: This script changes paths in a parameters.csv that are specific to our clusters
#       If you want to use this somewhere else you have to change that in the script"


set -e
set -u

module load Python

cohort=
project_dir=
tmpdir=
script_dir=$(dirname "$0")

main(){
    parse_commandline "$@"
    # move to project dir if it exists.
    # I prefer making the project dir outside of this script in case wrong directory is given
    if [ -d "$project_dir" ];
    then
        echo "Changing directory to $project_dir"
        cd $project_dir
    else
        echo "ERROR: $project_dir does not exist"
        exit 1;
    fi
    clone_pipelines
    adjust_workflows
    change_protocols
    change_parameter_files
    make_samplesheets
    change_prepare_scripts
    cohort_specific_steps
    make_pipeline_scripts
    cd -
}

usage(){
    # print the usage of the programme
    programname=$0
    echo "usage: $programname -c cohort -p project_directory -t tmp04"
    echo "  -c      provide the cohort to prepare pipeline for (mandatory)"
    echo "  -p      Base of the project_dir where pipeline scripts will be put (mandatory)"
    echo "  -t      tmpdir of the cluster (e.g. tmp03 for boxy, tmp04 for calculon). Will use /groups/$TMPDIR/.../"
    echo "  -h      display help"
    exit 1
}

clone_pipelines(){
    # Clone the relevant github repositories and move some files around
    echo "Cloning pipeline...."

    # In case the program has already run in current direcotry
    rm -rf Public_RNA-seq_QC
    rm -rf Public_RNA-seq_quantification
    git clone https://github.com/npklein/molgenis-pipelines.git
    # Move the relevant pipeline directories to the main project_dir
    mv molgenis-pipelines/compute5/Public_RNA-seq_QC/ .
    mv molgenis-pipelines/compute5/Public_RNA-seq_quantification/ .
    rm -rf molgenis-pipelines
}

adjust_workflows(){
    # Adjust the molgenis compute workflows to only run the steps necesarry for this project and to add new steps
    echo "Adjusting workflows..."

    # Remove unused workflows to make workflow directory less messy
    mv Public_RNA-seq_QC/workflows/workflowSTAR.csv /tmp/workflowSTAR.csv
    rm Public_RNA-seq_QC/workflows/*
    mv /tmp/workflowSTAR.csv Public_RNA-seq_QC/workflows/

    # Remove all the steps we don't need from the workflow
    # At the moment there are none to remove

    # Change/add steps that are not in by default
    sed -i 's;Kallisto,../protocols/Kallisto.sh,;Sailfish,../protocols/Sailfish.sh,;' Public_RNA-seq_quantification/workflows/workflow.csv
}



change_protocols(){
    # Adjust the molgenis compute protocols based on needs of the brain eQTL project
    echo "Changing protocols..."

    # add a line to delete the unfiltered BAM after cramming
    echo "echo \"remove \${unfilteredBamDir}/\${uniqueID}.bam\"" >> Public_RNA-seq_QC/protocols/CreateCramFiles.sh
    echo "rm \${unfilteredBamDir}/\${uniqueID}.bam" >> Public_RNA-seq_QC/protocols/CreateCramFiles.sh

    # Although for ENA we do add in readgroup information as the new version of GATK needs it,
    # this was not done for the other cohorts. Therefore, remove  METRIC_ACCUMULATION_LEVEL here as well
    # Otherwise, tries to do it per readgroud. Now does it per file
    sed -i '/METRIC_ACCUMULATION_LEVEL/d' Public_RNA-seq_QC/protocols/CollectRnaSeqMetrics.sh
}

change_parameter_files(){
    # Change those parameters in parameters.csv that are old (e.g. old path to resource files) or cluster specific (e.g. tmp03/tmp04)
    echo "Changing parameter files..."

    # Change the alignment pipeline parameter file
    # NOTE: The replacemets are cluster specific, but don't want to make this command line options because that would make too many of them
    #       Either change below code or change the parameters.csv file
    sed -i 's;group,umcg-wijmenga;group,umcg-biogen;' Public_RNA-seq_QC/parameter_files/parameters.csv
    sed -i "s;resDir,/groups/umcg-wijmenga/tmp04/resources/;resDir,/apps/data/;" Public_RNA-seq_QC/parameter_files/parameters.csv
    sed -i "s;resDir,/groups/umcg-wijmenga/tmp03/resources/;resDir,/apps/data/;" Public_RNA-seq_QC/parameter_files/parameters.csv
    sed -i "s;projectDir,\${root}/\${group}/\${tmp}/projects/umcg-ndeklein/\${project}/;projectDir,${project_dir}/results/;" Public_RNA-seq_QC/parameter_files/parameters.csv
    sed -i 's;STARindex;STARindex,${resDir}/ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_24/STAR/${starVersion}/;' Public_RNA-seq_QC/parameter_files/parameters.csv
    sed -i 's;alignmentDir,${projectDir}/hisat/;alignmentDir,${projectDir}/star;' Public_RNA-seq_QC/parameter_files/parameters.csv
    sed -i 's;fastqExtension,.gz;fastqExtension,.fq.gz;' Public_RNA-seq_QC/parameter_files/parameters.csv
    sed -i 's;goolf-1.7.20;foss-2015b;g' Public_RNA-seq_QC/parameter_files/parameters.csv
    sed -i 's;fastqExtension,.fq.gz;fastqExtension,.fastq.gz;' Public_RNA-seq_QC/parameter_files/parameters.csv
    sed -i 's;1.102-Java-1.7.0_80;1.119-Java-1.7.0_80;' Public_RNA-seq_QC/parameter_files/parameters.csv
    sed -i 's;onekgGenomeFasta,${resDir}/${genomeBuild}/indices/human_g1k_v${human_g1k_vers}.fasta;onekgGenomeFasta,${resDir}/ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_24/GRCh38.p5.genome.fa;' Public_RNA-seq_QC/parameter_files/parameters.csv
    sed -i 's;genesRefFlat,${resDir}/picard-tools/Ensembl${ensemblVersion}/${genomeLatSpecies}.${genomeGrchBuild}.${ensemblVersion}.refflat;genesRefFlat,${resDir}/ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_24/gencode.v24.chr_patch_hapl_scaff.annotation.refflat;' Public_RNA-seq_QC/parameter_files/parameters.csv
    sed -i 's;rRnaIntervalList,${resDir}//picard-tools/Ensembl${ensemblVersion}/${genomeLatSpecies}.${genomeGrchBuild}.${ensemblVersion}.rrna.interval_list;rRnaIntervalList,${resDir}/ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_24/gencode.v24.chr_patch_hapl_scaff.annotation.rRNA.interval_list;' Public_RNA-seq_QC/parameter_files/parameters.csv

    # Change the qunatification pipeline parameter file
    sed -i 's;group,umcg-wijmenga;group,umcg-biogen;' Public_RNA-seq_quantification/parameter_files/parameters.csv
    sed -i "s;tmp03;$tmpdir;" Public_RNA-seq_quantification/parameter_files/parameters.csv
    sed -i "s;projectDir,\${root}/\${group}/\${tmp}/projects/umcg-ndeklein/\${project}/;projectDir,${project_dir}/results/;" Public_RNA-seq_quantification/parameter_files/parameters.csv
    sed -i "s;projects/umcg-ndeklein/\${project};biogen/input/${cohort}/results/;" Public_RNA-seq_quantification/parameter_files/parameters.csv
    chr38gtf="/apps/data/ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_24/gencode.v24.chr_patch_hapl_scaff.annotation.gtf.gz"
    sed -i "s;annotationGtf,/apps/data/ftp.ensembl.org/pub/release-75/gtf/homo_sapiens/Homo_sapiens.GRCh37.75.gtf;annotationGtf,${chr38gtf};" Public_RNA-seq_quantification/parameter_files/parameters.csv
    echo "bedtoolsVersion,2.25.0-foss-2015b" >> Public_RNA-seq_quantification/parameter_files/parameters.csv
    echo "picardVersion,2.10.0-foss-2015b-Java-1.8.0_74" >> Public_RNA-seq_quantification/parameter_files/parameters.csv
    echo "iolibVersion,1.14.6-foss-2015b" >> Public_RNA-seq_quantification/parameter_files/parameters.csv
    echo "resDir,/apps/data/" >> Public_RNA-seq_quantification/parameter_files/parameters.csv
    echo 'onekgGenomeFasta,${resDir}/ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_24/GRCh38.p5.genome.fa' >> Public_RNA-seq_quantification/parameter_files/parameters.csv
    sed -i 's;htseqVersion,0.6.1p1-foss-2015b;htseqVersion,0.9.1-foss-2015b-Python-2.7.11;' Public_RNA-seq_quantification/parameter_files/parameters.csv
    # most of the protocols are not stranded, so change here. If protocol is stranded for one of the
    # cohorts it will be adjusted in cohort specific method below
    sed -i 's;stranded,reverse;stranded,no;' Public_RNA-seq_quantification/parameter_files/parameters.csv


    # Change in both
    sed -i 's;genomeBuild,b37;genomeBuild,b38;' Public_RNA-seq*/parameter_files/parameters.csv
    sed -i 's;genomeGrchBuild,GRCh37;genomeGrchBuild,GRCh38;' Public_RNA-seq*/parameter_files/parameters.csv
    sed -i 's;human_g1k_vers,37;human_g1k_vers,38;' Public_RNA-seq*/parameter_files/parameters.csv
    sed -i 's;ensemblVersion,75;ensemblVersion,?;' Public_RNA-seq*/parameter_files/parameters.csv
}


make_samplesheets(){
    # Make the samplesheets. How the samplesheet is made is dependent om the cohort
    echo "Making samplesheets..."
    rm Public_RNA-seq_QC/samplesheet1.csv
    mkdir -p Public_RNA-seq_QC/samplesheets/

    samplesheet_script_dir=$script_dir/samplesheet_scripts/
    if [[ "$cohort" == "TargetALS" ]];
    then
        echo "ERROR: Don't need to get genotypes for the TargetALS samples. Because the pipeline needs to be set up quite differently, use make_alignmentAndQuantification_pipeline.sh instead"
    elif [[ "$cohort" == "CMC" ]];
    then
        echo "ERROR: Don't need to get genotypes for the CMC samples. Because the pipeline needs to be set up quite differently, use make_alignmentAndQuantification_pipeline.sh instead"
    elif [[ "$cohort" == "Braineac" ]];
    then
        echo "ERROR: Don't need to get genotypes for the Braineac samples. Because the pipeline needs to be set up quite differently, use make_alignmentAndQuantification_pipeline.sh instead"
    elif [[ "$cohort" == "ENA" ]];
    then
        # Need to know where to find samplesheet_ENA_20181212.tx, this is in the brain_eQTL github directory. Since this script is also in this directory, find the directory like so (and add it to parameters file):
        brain_eQTL_dir="$( cd "$( dirname $( dirname "${BASH_SOURCE[0]}" ) )" >/dev/null && pwd )"
        python $samplesheet_script_dir/make_samplesheet_ENA.py $brain_eQTL_dir/ENA/ENA_samplesheets/samplesheet_ENA_20181212.txt \
                                                               /scratch/umcg-ndeklein/tmp03/ENA/pipelines/results/fastq/
    else
        echo "No code written for cohort $cohort"
        exit 1;
    fi
}

change_prepare_scripts(){
    # Change the molgenis compute prepare scirpts
    echo "Chaning prepare scripts..."

    # Do general changes for the alignment pipeline
    sed -i 's;/path/to/molgenis-pipelines/compute5/Public_RNA-seq_QC/;;' Public_RNA-seq_QC/prepare_Public_RNA-seq_QC.sh
    sed -i "s;/groups/umcg-wijmenga/tmp04/umcg-ndeklein/molgenis-pipelines/compute5/Public_RNA-seq_QC/;;" Public_RNA-seq_QC/prepare_Public_RNA-seq_QC.sh
    sed -i "s;parameters.converted.csv;${project_dir}/Public_RNA-seq_QC/parameter_files/parameters.converted.csv;" Public_RNA-seq_QC/prepare_Public_RNA-seq_QC.sh
    sed -i "s;workflow.csv;${project_dir}/Public_RNA-seq_QC/workflows/workflowSTAR.csv;" Public_RNA-seq_QC/prepare_Public_RNA-seq_QC.sh
    sed -i "s;-rundir /groups/umcg-wijmenga/tmp04/umcg-ndeklein/rundirs/QC/;-rundir ${project_dir}/alignment/alignmentDir;" Public_RNA-seq_QC/prepare_Public_RNA-seq_QC.sh
    sed -i "s;/groups/umcg-wijmenga/tmp04/umcg-ndeklein/samplesheets/;${project_dir}/Public_RNA-seq_QC/samplesheets/;" Public_RNA-seq_QC/prepare_Public_RNA-seq_QC.sh

    # Do general changes for the quantification pipeline
    sed -i "s;workflows/workflow.csv;${project_dir}/Public_RNA-seq_quantification/workflows/workflow.csv;" Public_RNA-seq_quantification/prepare_quantification.sh
    sed -i "s;parameter_files/;${project_dir}/Public_RNA-seq_quantification/parameter_files/;" Public_RNA-seq_quantification/prepare_quantification.sh


    # Do specific changes per samplesheet batch
    mkdir Public_RNA-seq_QC/prepare_scripts/
    mkdir Public_RNA-seq_quantification/prepare_scripts/
    for samplesheet in `ls Public_RNA-seq_QC/samplesheets/samplesheet*txt`;
    do
        name=$(echo ${samplesheet} | awk -F"." '{print $2}')

        # Change it for the alignment pipeline per batch
        echo "making prepare script using $samplesheet: Public_RNA-seq_QC/prepare_scripts/prepare_Public_RNA-seq_QC.$name.sh"
        rsync -P Public_RNA-seq_QC/prepare_Public_RNA-seq_QC.sh Public_RNA-seq_QC/prepare_scripts/prepare_Public_RNA-seq_QC.$name.sh
        sed -i "s;samplesheet.csv;samplesheet_${cohort}_RNA.$name.txt;" Public_RNA-seq_QC/prepare_scripts/prepare_Public_RNA-seq_QC.$name.sh
        sed -i "s;alignmentDir;$name;" Public_RNA-seq_QC/prepare_scripts/prepare_Public_RNA-seq_QC.$name.sh

        # Change it for the quantificaiton pipeline per batch
        rsync -P Public_RNA-seq_quantification/prepare_quantification.sh Public_RNA-seq_quantification/prepare_scripts/prepare_quantification.$name.sh
        sed -i "s;samplesheet.csv;${project_dir}/Public_RNA-seq_QC/samplesheets/samplesheet_${cohort}_RNA.$name.txt;" Public_RNA-seq_quantification/prepare_scripts/prepare_quantification.$name.sh
        sed -i "s;alignmentDir;$name;" Public_RNA-seq_quantification/prepare_scripts/prepare_quantification.$name.sh
        sed -i "s;-rundir results/;-rundir ${project_dir}/quantification/$name;" Public_RNA-seq_quantification/prepare_scripts/prepare_quantification.$name.sh
    done
}


make_pipeline_scripts(){
    # Make the pipeline scripts using Molgenis Compute
    echo "Maing pipeline scripts..."
    echo $PWD

    # convert the parameter files to wide format now instead of in the change_parameters function because the cohort_specific_steps function might have changed some of them
    bash Public_RNA-seq_QC/parameter_files/convert.sh Public_RNA-seq_QC/parameter_files/parameters.csv Public_RNA-seq_QC/parameter_files/parameters.converted.csv
    bash Public_RNA-seq_QC/parameter_files/convert.sh Public_RNA-seq_quantification/parameter_files/parameters.csv Public_RNA-seq_quantification/parameter_files/parameters.converted.csv
    cd Public_RNA-seq_QC/prepare_scripts;
    for f in *sh;
    do
        bash $f;
    done
    cd -

    cd Public_RNA-seq_quantification/prepare_scripts
    for f in *sh;
    do
        bash $f;
    done
    cd -
}


cohort_specific_steps(){
    # Collection of cohort specific steps
    echo "Running cohort specific steps..."

    if [[ "$cohort" == "ENA" ]];
    then
        echo "ENA specific methods..."
        # Need to know where to find download_ENA_samples.py, this is in the brain_eQTL github directory. Since this script is also in this directory, find the directory like so (and add it to parameters file):
        brain_eQTL_dir="$( cd "$( dirname $( dirname "${BASH_SOURCE[0]}" ) )" >/dev/null && pwd )"
        echo "brainDir,$brain_eQTL_dir" >> Public_RNA-seq_QC/parameter_files/parameters.csv
        echo "enaSamplesheet,$brain_eQTL_dir/ENA/ENA_samplesheets/samplesheet_ENA_20181212.txt" >> Public_RNA-seq_QC/parameter_files/parameters.csv
        # Because we only need to download from ENA if the cohort is ENA, copy over
        rsync -P $script_dir/modified_protocols/DownloadFromENA.sh Public_RNA-seq_QC/protocols/
        # Have to add the download part before the start of the pipeline (2i inserts the text at 2nd line)
        sed -i '2iDownloadFromENA,../protocols/DownloadFromENA.sh,' Public_RNA-seq_QC/workflows/workflowSTAR.csv
        sed -i 's;STARMapping,../protocols/STARMapping.sh,;STARMapping,../protocols/STARMapping.sh,DownloadFromENA;' Public_RNA-seq_QC/workflows/workflowSTAR.csv
        sed -i 's;FastQC,../protocols/Fastqc.sh,;FastQC,../protocols/Fastqc.sh,DownloadFromENA;' Public_RNA-seq_QC/workflows/workflowSTAR.csv

        # for testing only do first 3 jobs
#        echo "step,protocol,dependencies" > Public_RNA-seq_QC/workflows/workflowSTAR.csv
#        echo "DownloadFromENA,../protocols/DownloadFromENA.sh," >> Public_RNA-seq_QC/workflows/workflowSTAR.csv
#        echo "STARMapping,../protocols/STARMapping.sh,DownloadFromENA" >> Public_RNA-seq_QC/workflows/workflowSTAR.csv
#        echo "CreateCramFiles,../protocols/CreateCramFiles.sh,STARMapping" >> Public_RNA-seq_QC/workflows/workflowSTAR.csv
#        echo "FastQC,../protocols/Fastqc.sh,DownloadFromENA" >> Public_RNA-seq_QC/workflows/workflowSTAR.csv

        # Different molgenis compute script is installed on Peregrine where the public data is run, so change
        for prepare_script in Public_RNA-seq*/prepare_scripts/*sh;
        do
            sed -i 's;v16.05.1-Java-1.8.0_45;v16.11.1-Java-1.8.0_74;' $prepare_script
        done

        # have to change a lot of parameters because the script locations are all different
        sed -i 's;WORKDIR,/groups/;WORKDIR,/scratch/;' Public_RNA-seq*/parameter_files/parameters.csv
        sed -i 's;group,umcg-biogen;group,umcg-ndeklein;' Public_RNA-seq*/parameter_files/parameters.csv
        sed -i "s;resDir,/apps/data/;resDir,/data/umcg-ndeklein/apps/data/;" Public_RNA-seq_QC/parameter_files/parameters.csv
    fi
}

parse_commandline(){
    # Parse the command line arguments
    echo "Parsing commandline..."

    # Check to see if at least one argument is given
    if [ $# -eq 0 ]
    then
        echo "ERROR: No arguments supplied"
        usage
        exit 1;
    fi

    while [[ $# -ge 1 ]]; do
        case $1 in
            -c | --cohort )         shift
                                    cohort=$1
                                    ;;
            -p | --project_dir )    shift
                                    project_dir=$1
                                    ;;
            -t | --tmpdir )         shift
                                    tmpdir=$1
                                    ;;
            -h | --help )           usage
                                    exit
                                    ;;
            * )                     echo "ERROR: Undexpected argument: $1"
                                    usage
                                    exit 1
        esac
        shift
    done
    echo "Cohort = $cohort"
    echo "Project directory = $project_dir"

    # if -z tests if variable is empty. Make sure the relevant variables are set
    if [ -z "$cohort" ];
    then
        echo "ERROR: -c/--cohort not set!"
        usage
        exit 1;
    fi
    if [ -z "$project_dir" ];
    then
        echo "ERROR: -p/--project_dir not set!"
        usagae
        exit 1;
    fi
    if [ -z "$tmpdir" ];
    then
        echo "ERROR: -t/--tmpdir not set!"
        usagae
        exit 1;
    fi
    echo "Making pipeline..."
}

# [[ ${BASH_SOURCE[0]} = "$0" ]] -> main does not run when this script is sourced
# main "$@" -> Send the arguments to the main function (this way project flow can be at top)
# exit -> safeguard against the file being modified while it is interpreted
[[ ${BASH_SOURCE[0]} = "$0" ]] && main "$@"; exit;
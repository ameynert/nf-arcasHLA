#!/usr/bin/env nextflow

def helpMessage() {
    log.info"""
    Usage:

    The typical command for running the pipeline is as follows:

    nextflow run ameynert/nf-arcasHLA --input '*.bam' --outdir 'output' --name 'batch_name'

    """.stripIndent()
}

// Show help message
params.help = false
if (params.help){
    helpMessage()
    exit 0
}


// Defines reads and outputdir
params.input = '*.bam'
params.outdir = 'output'

// Header 
println "['Pipeline Name']     = ameynert/nf-arcasHLA"
println "['Pipeline Version']  = workflow.manifest.version"
println "['Input']             = $params.input"
println "['Output dir']        = $params.output"
println "['Name']              = $params.name"
println "['Working dir']       = workflow.workDir"
println "['Container Engine']  = workflow.containerEngine"
println "['Current home']      = $HOME"
println "['Current user']      = $USER"
println "['Current path']      = $PWD"
println "['Working dir']       = workflow.workDir"
println "['Script dir']        = workflow.projectDir"
println "['Config Profile']    = workflow.profile"
println "========================================================"

/*
 * Create a channel for input alignment files
 */
Channel
  .fromFilePairs( params.input, size: 1 )
  .ifEmpty { exit 1, "Cannot find any files matching ${params.input}\nNB: Path needs to be enclosed in quotes!\nNB: Path requires at least one * wildcard!" }
  .set { input_ch }


/*
 * Extract reads
 */
process extract_reads {

    input:
    set val(name), file(alignment) from input_ch

    output:
    file('*.log') into extract_log_ch
    set val(name), file('*.fq.gz') into reads_ch

    script:
    """
    arcasHLA extract ${alignment} -o . --unmapped -t ${task.cpus} --log ${name}.extract.log --temp \$TMPDIR
    """
}

/*
 * Genotype
 */
process genotype {

    input:
    set val(name), file(reads) from reads_ch

    output:
    file("*.log")
    file('*.json') into genotype_ch

    script:
    """
    arcasHLA genotype ${reads} -g A,B,C,DPB1,DQB1,DQA1,DRB1 -o . -t ${task.cpus} --log ${name}.genotype.log --temp \$TMPDIR
    """
}

/*
 * Merge results
 */
process merge {

   publishDir params.outdir, mode: 'copy'
   validExitStatus 0,1

   input:
   file(output) from genotype_ch.collect()

   output:
   file('*.tsv') into merged_ch

   script:
   """
   arcasHLA merge --indir . --outdir . --run ${params.name}
   perl -pi -e 's/Aligned//' ${params.name}.genotypes.tsv
   """

}

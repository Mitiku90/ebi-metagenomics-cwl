cwlVersion: v1.0
class: Workflow
label: EMG pipeline v3.0 (single end version)

requirements:
 - class: SubworkflowFeatureRequirement
 - class: SchemaDefRequirement
   types: 
    - $import: ../tools/FragGeneScan-model.yaml
    - $import: ../tools/trimmomatic-sliding_window.yaml
    - $import: ../tools/trimmomatic-end_mode.yaml
    - $import: ../tools/trimmomatic-phred.yaml

inputs:
  reads:
    type: File
    format: edam:format_1930  # FASTQ
  fraggenescan_model: ../tools/FragGeneScan-model.yaml#model
  16S_model:
    type: File
    format: edam:format_1370  # HMMER
  5S_model:
    type: File
    format: edam:format_1370  # HMMER
  23S_model:
    type: File
    format: edam:format_1370  # HMMER
  tRNA_model:
    type: File
    format: edam:format_1370  # HMMER
  go_summary_config: File

outputs:
  processed_sequences:
    type: File
    outputSource: find_SSUs_and_mask/masked_sequences
  predicted_CDS:
    type: File
    outputSource: ORF_prediction/predictedCDS
  functional_annotations:
    type: File
    outputSource: functional_analysis/functional_annotations
  go_summary:
    type: File
    outputSource: functional_analysis/go_summary
  otu_table_summary:
    type: File
    outputSource: 16S_taxonomic_analysis/otu_table_summary
  tree:
    type: File
    outputSource: 16S_taxonomic_analysis/tree
  biom_json:
    type: File
    outputSource: 16S_taxonomic_analysis/biom_json

steps:
  trim_quality_control:
    doc: |
      Low quality trimming (low quality ends and sequences with < quality scores
      less than 15 over a 4 nucleotide wide window are removed)
    run: ../tools/trimmomatic.cwl
    in:
      reads1: reads
      phred: { default: '33' }
      leading: { default: 3 }
      trailing: { default: 3 }
      end_mode: { default: SE }
      minlen: { default: 100 }
      slidingwindow:
        default:
          windowSize: 4
          requiredQuality: 15
    out: [reads1_trimmed]

  convert_trimmed-reads_to_fasta:
    run: ../tools/fastq_to_fasta.cwl
    in:
      fastq: trim_quality_control/reads1_trimmed
    out: [ fasta ]

  find_SSUs_and_mask:
    run: rna-selector.cwl
    in: 
      reads: convert_trimmed-reads_to_fasta/fasta
      16S_model: 16S_model
      5S_model: 5S_model
      23S_model: 23S_model
      tRNA_model: tRNA_model
    out: [ 16S_matches, masked_sequences ]

  ORF_prediction:
    doc: |
      Find reads with predicted coding sequences (pCDS) above 60 nucleotides in
      length.
    run: ../tools/FragGeneScan1_20.cwl
    in:
      sequence: find_SSUs_and_mask/masked_sequences
      completeSeq: { default: false }
      model: fraggenescan_model
    out: [predictedCDS]

  functional_analysis:
    doc: |
      Matches are generated against predicted CDS, using a sub set of databases
      (Pfam, TIGRFAM, PRINTS, PROSITE patterns, Gene3d) from InterPro. 
    run: functional_analysis.cwl
    in:
      predicted_CDS: ORF_prediction/predictedCDS
      go_summary_config: go_summary_config
    out: [ functional_annotations, go_summary]

  16S_taxonomic_analysis:
    doc: |
      16s rRNA are annotated using the Greengenes reference database
      (default closed-reference OTU picking protocol with Greengenes
      13.8 reference with reverse strand matching enabled).
    run: 16S_taxonomic_analysis.cwl
    in:
      16S_matches: find_SSUs_and_mask/16S_matches
    out: [ otu_table_summary, tree, biom_json ]

$namespaces:
 edam: http://edamontology.org/
 s: http://schema.org/
$schemas:
 - http://edamontology.org/EDAM_1.16.owl
 - https://schema.org/docs/schema_org_rdfa.html

s:license: "https://www.apache.org/licenses/LICENSE-2.0"
s:copyrightHolder: "EMBL - European Bioinformatics Institute"

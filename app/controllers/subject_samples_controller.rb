class SubjectSamplesController < ApplicationController
  before_action :authenticate_user!

  respond_to :html

  # REST-fully renders SubjectSample <read>
  #
  # GET /subject_sample/<subject_sample>
  def show
    # NOTE: params[:id] here is a SUBJECT ID as the whole page is all about subject.
    @subject_id = params[:id]
    @samples = SubjectSample.find(current_user, @subject_id)

    if @samples.nil?
      raise ActionController::RoutingError.new("#{ @subject_id } not found")
    end

    @measures = SubjectMeasure.find(current_user, @subject_id)
  end

  def igv
    # NOTE: params[:id] here is a SAMPLE ID, used by the read viewer.
    @subject_sample_id = params[:id]

    @sample = SubjectSample.find_one_by_sample_id(current_user, @subject_sample_id)

    if @sample.nil?
      raise ActionController::RoutingError.new("#{ @subject_sample_id } not found")
    end

    @subject = Subject.find(current_user, @sample.indexid)

    @locus = params[:locus]
    @platform = params[:platform]
    @tracks = [
      {
        type: "sequence",
        visibilityWindow: 100000,
        order: 9999
      },
      # {
      #   # url: "//dn7ywbm9isq8j.cloudfront.net/annotations/hg38/genes/gencode.v38.collapsed.bed",
      #   # url: "ftp://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_32/gencode.v32.annotation.gtf.gz",
      #   # url: "gs://igv-files/gencode.v32.annotation.bed",
      #   url: "/assets/igv/gencode.v32.annotation.bed",
      #   label: "Genes",
      #   visibilityWindow: 100000,
      #   order: 10000
      # },
    ]

    cramUrl = 'gs://mssng-share-hg38/released/genomes/ILMN/CRAM'
    vcfUrl = 'gs://mssng-share-hg38/released/genomes/ILMN/VCF/FAMILIES'

    if @platform.eql?('Complete Genomics')
      @tracks << {
        type: 'vcf',
        sourceType: 'gcs',
        url: "gs://mssng-share-hg38/released/genomes/CGI/VCF/#{@subject_sample_id}.PICARD_hg38.vcf.gz?userProject=example-gcp-project",
        indexURL: "gs://mssng-share-hg38/released/genomes/CGI/VCF/#{@subject_sample_id}.PICARD_hg38.vcf.gz.tbi?userProject=example-gcp-project",
        label: 'Variants (Complete Genomics)',
        visibilityWindow: 30000,
        order: 9998,
        oauthToken: current_user.credentials.access_token
      }
    else
      @tracks << {
        format: 'vcf',
        sourceType: 'gcs',
        url: "#{vcfUrl}/#{@subject.familyid}.vcf.gz?userProject=example-gcp-project",
        indexURL: "#{vcfUrl}/#{@subject.familyid}.vcf.gz.tbi?userProject=example-gcp-project",
        label: 'Variants (Illumina)',
        visibilityWindow: 30000,
        order: 9998,
        oauthToken: current_user.credentials.access_token
      }

      @tracks << {
        format: 'cram',
        type: 'alignment',
        sourceType: 'gcs',
        sequences: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "X", "Y", "MT"],
        url: "#{cramUrl}/#{@subject_sample_id}_recal.cram?userProject=example-gcp-project",
        indexURL: "#{cramUrl}/#{@subject_sample_id}_recal.cram.crai?userProject=example-gcp-project",
        label: 'Reads (CRAM)',
        visibilityWindow: 100000,
        order: 9997,
        oauthToken: current_user.credentials.access_token
      }
    end
  end

end

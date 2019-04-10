class SubjectSamplesController < ApplicationController
  before_action :authenticate_user!

  respond_to :html

  # REST-fully renders SubjectSample <read>
  #
  # GET /subject_sample/<subject_sample>
  def show
    @subject_sample = SubjectSample.find(current_user, params[:id])
    @subject_sample.measures = SubjectMeasure.find(current_user, params[:id])
    respond_with(@subject_sample)
  end

  def igv
    @subject_sample_id = params[:id]
    @locus = params[:locus]
    @platform = params[:platform]
    @chr = @locus.split(":").first
    @call_set_id = params[:call_set_id]
    @tracks = [
      {
        type: "sequence",
        visibilityWindow: 100000,
        order: 9999
      },
      {
        url: "//dn7ywbm9isq8j.cloudfront.net/annotations/hg19/genes/gencode.v18.collapsed.bed",
        label: "Genes",
        visibilityWindow: 100000,
        order: 10000
      }
    ]
    if @platform.eql?('Complete Genomics')
      @tracks << {
        type: 'vcf',
        sourceType: 'gcs',
        url: "gs://mssng-share/released/genomes/CGI/VCF/#{@subject_sample_id}/real_variants.vcf.gz?userProject=example-gcp-project",
        indexURL: "gs://mssng-share/released/genomes/CGI/VCF/#{@subject_sample_id}/real_variants.vcf.gz.tbi?userProject=example-gcp-project",
        label: 'Variants',
        visibilityWindow: 30000,
        order: 9998,
        oauthToken: current_user.credentials.access_token
      }
    else
      @tracks << {
        type: 'vcf',
        sourceType: 'gcs',
        url: "gs://mssng-share/released/genomes/ILMN/VCF/#{@subject_sample_id}/recalibrated_variants.vcf.gz?userProject=example-gcp-project",
        indexURL: "gs://mssng-share/released/genomes/ILMN/VCF/#{@subject_sample_id}/recalibrated_variants.vcf.gz.tbi?userProject=example-gcp-project",
        label: 'Variants',
        visibilityWindow: 30000,
        order: 9998,
        oauthToken: current_user.credentials.access_token
      }

      @tracks << {
        sourceType: 'shardedBam',
        type: 'alignment',
        sources: {
          sequences: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "X", "Y", "MT"],
          url: "gs://mssng-share/released/genomes/ILMN/BAM/#{@subject_sample_id}/recalibrated.$CHR.bam?userProject=example-gcp-project",
          indexURL: "gs://mssng-share/released/genomes/ILMN/BAM/#{@subject_sample_id}/recalibrated.$CHR.bam.bai?userProject=example-gcp-project",
        },
        label: 'Reads',
        visibilityWindow: 100000,
        order: 9997
      }
    end
  end

end

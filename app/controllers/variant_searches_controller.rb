# 7 REST-ful actions on VariantSearch(s)
class VariantSearchesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_variant_search, only: [:show, :edit, :update, :destroy]
  before_action :set_user, only: [:index, :create, :saved, :delete_all, :delete_multiple]

  respond_to :html
  respond_to :xlsx, only: [:show]

  # REST-fully renders all VariantSearch(s)
  #
  # GET /variant_searches
  def index
    @variant_searches = @user.variant_searches.not_saved
    respond_with(@variant_searches)
  end

  def saved
    @variant_searches = @user.variant_searches.saved
    respond_with(@variant_searches)
  end

  def delete_multiple
    @user.variant_searches.saved.where(id: params["variant_searches"]).destroy_all
    redirect_to action: :saved
  end

  def delete_all
    @user.variant_searches.not_saved.destroy_all
    redirect_to action: :index
  end

  # REST-fully renders VariantSearch <variant_search>
  #
  # GET /variant_searches/<variant_search>
  def show
    @requested_timestamp = Time.now
    respond_with(@variant_search) do |format|
      format.html {
        @variant_search.limited = true
      }
      format.xlsx {
        response.headers['Content-Disposition'] = "'attachment; filename=\"#{@variant_search.name.parameterize(separator: "_")}.xlsx\""
      }
      format.text {
        if params['no_dl'].nil?
          send_data render_to_string, filename: @variant_search.name.parameterize(separator: "_") + '.tsv', disposition: 'attachment', layout: false
        end
      }
    end
  end

  # REST-fully renders a new unsaved VariantSearch
  #
  # GET /variant_searches/new
  def new
    @variant_search = VariantSearch.new(
        name: Time.now.strftime('%d/%m/%Y-%H:%M:%S'),
        passing: '1',
        affection: 'affected',
        impacts: ["high"],
        frequency: 0.01,
        frequency_operator: '<=',
        upstream_bases: 1000,
    )
    respond_with(@variant_search)
  end

  # REST-fully renders an editable VariantSearch
  #
  # GET /variant_searches/<variant_search>/edit
  def edit
  end

  # REST-fully creates a VariantSearch
  #
  # @param name [String]
  # POST /variant_searches
  def create
    # logger.info "***** CREATE with #{secure_params}"
    @variant_search = VariantSearch.new(secure_params)
    @variant_search.user = @user
    if @variant_search.save
      # flash[:notice] = dt("notices.create", model: @variant_search.name)
    end
   respond_with(@variant_search)
   # respond_with(@variant_search, :location => variant_searches_url)
  end

  # REST-fully updates a VariantSearch
  #
  # @param name [String]
  # PUT  /variant_searches/<variant_search>
  def update
    truncated_preference = truncate_preference(secure_params)
    if @variant_search.update(truncated_preference)
      # flash[:notice] = dt("notices.update", model: @variant_search.name)
    end
    # if truncated_preference.include?('saved')
    #   respond_with(@variant_search, location: search_variant_searches_url)
    # else
      respond_with(@variant_search)
    # end
  end

  # REST-fully destroys a VariantSearch
  #
  # DELETE  /variant_searches/<variant_search>
  def destroy
    @variant_search.destroy
    respond_with(@variant_search, location: variant_searches_url)
  end

  def search
    @variant_search = VariantSearch.new(passing: '1',
                                        affection: 'affected',
                                        impacts: ["high"],
                                        frequency: 0.01,
                                        frequency_operator: '<=',
                                        upstream_bases: 1000,)
  end

  private
    def set_variant_search
      @variant_search = VariantSearch.find(params[:id])
    end

    def set_user
      @user = current_user
    end

    def secure_params
      params.require(:variant_search).permit(
        :uploaded_gene_file,
        :uploaded_subject_file,
        :uploaded_sample_file,
        :dbsnp,
        :uploaded_bed_file,
        :saved,
        :search,
        :name,
        :passing,
        :denovo,
        :variant,
        :dna_source,
        :platform,
        :gender,
        :chromosome,
        :start_position,
        :end_position,
        :upstream_bases,
        :reference_allele,
        :alternate_allele,
        :frequency,
        :frequency_operator,
        :zygosity,
        :stringy_gene_ids,
        :stringy_index_ids,
        :stringy_submitted_ids,
        :affection,
        :role,
        :effects => [],
        :impacts => [],
        :paths => [],
      )
    end

end

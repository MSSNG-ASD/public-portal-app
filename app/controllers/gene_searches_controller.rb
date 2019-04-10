# 7 REST-ful actions on GeneSearch(s)
class GeneSearchesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_gene_search, only: [:show, :edit, :update, :destroy]
  before_action :set_user, only: [:index, :create, :saved, :delete_all, :delete_multiple]

  respond_to :html

  # REST-fully renders all GeneSearch(s)
  #
  # GET /gene_searches
  def index
    @gene_searches = @user.gene_searches.not_saved
    respond_with(@gene_searches)
  end

  def saved
    @gene_searches = @user.gene_searches.saved
    respond_with(@gene_searches)
  end

  def delete_multiple
    @user.gene_searches.saved.where(id: params["gene_searches"]).destroy_all
    redirect_to action: :saved
  end

  def delete_all
    @user.gene_searches.not_saved.destroy_all
    redirect_to action: :index
  end

  # REST-fully renders GeneSearch <read>
  #
  # GET /gens/<gene_search>
  def show
    respond_with(@gene_search)
  end

  # REST-fully renders a new unsaved GeneSearch
  #
  # GET /gens/new
  def new
    @gene_search = GeneSearch.new(name: Time.now.strftime('%d/%m/%Y-%H:%M:%S'))
    respond_with(@gene_search)
  end

  # REST-fully renders an editable GeneSearch
  #
  # GET /gene_searches/<gene_search>/edit
  def edit
  end

  # REST-fully creates a GeneSearch
  #
  # @param name [String]
  # POST /gene_searches
  def create
    @gene_search = GeneSearch.new(secure_params)
    @gene_search.user = @user
    if @gene_search.save
      flash[:notice] = dt("notices.create", :model => @gene_search.name)
    end
    respond_with(@gene_search)
    # respond_with(@gene_search, :location => gene_searches_url)
  end

  # REST-fully updates a GeneSearch
  #
  # @param name [String]
  # PUT  /gene_searches/<gene_search>
  def update
    if @gene_search.update(secure_params)
      flash[:notice] = dt("notices.update", :model => @gene_search.name)
    end
    if secure_params.include?('saved')
      respond_with(@gene_search, :location => search_gene_searches_url)
    else
      respond_with(@gene_search)
    end
  end

  # REST-fully destroys a GeneSearch
  #
  # DELETE  /gene_searches/<gene_search>
  def destroy
    @gene_search.destroy
    respond_with(@gene_search, :location => gene_searches_url)
  end

  def search
    @gene_search = GeneSearch.new
  end
  
  private
    def set_gene_search
      @gene_search = GeneSearch.find(params[:id])
    end

    def set_user
      @user = current_user
    end
    
    def secure_params
      params.require(:gene_search).permit(:saved, :search, :name, :stringy_gene_ids, :stringy_go_ids, :stringy_hpo_ids, :stringy_mim_ids, inheritances: [])
    end

end

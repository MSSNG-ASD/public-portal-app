# 7 REST-ful actions on SubjectSampleSearch(s)
class SubjectSampleSearchesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_subject_sample_search, only: [:show, :edit, :update, :destroy, :download]
  before_action :set_user, only: [:index, :create, :saved, :delete_all, :delete_multiple]

  respond_to :html

  # REST-fully renders all SubjectSampleSearch(s)
  #
  # GET /subject_sample_searches
  def index
    @subject_sample_searches = @user.subject_sample_searches.not_saved
    respond_with(@subject_sample_searches)
  end

  def saved
    @subject_sample_searches = @user.subject_sample_searches.saved
    respond_with(@subject_sample_searches)
  end

  def delete_multiple
    @user.subject_sample_searches.saved.where(id: params["subject_sample_searches"]).destroy_all
    redirect_to action: :saved
  end

  def delete_all
    @user.subject_sample_searches.not_saved.destroy_all
    redirect_to action: :index
  end

  # REST-fully renders SubjectSampleSearch <subject_sample_search>
  #
  # GET /subject_sample_searches/<subject_sample_search>
  def show
    respond_with(@subject_sample_search)
  end

  # REST-fully renders a new unsaved SubjectSampleSearch
  #
  # GET /subject_sample_searches/new
  def new
    @subject_sample_search = SubjectSampleSearch.new(name: Time.now.strftime('%d/%m/%Y-%H:%M:%S'))
    respond_with(@subject_sample_search)
  end

  # REST-fully renders an editable SubjectSampleSearch
  #
  # GET /subject_sample_searches/<subject_sample_search>/edit
  def edit
  end

  # REST-fully creates a SubjectSampleSearch
  #
  # @param name [String]
  # POST /subject_sample_searches
  def create
    @subject_sample_search = SubjectSampleSearch.new(secure_params)
    @subject_sample_search.user = @user
    if @subject_sample_search.save
      flash[:notice] = dt("notices.create", model: @subject_sample_search.name)
    end
   respond_with(@subject_sample_search)
   # respond_with(@subject_sample_search, :location => subject_sample_searches_url)
  end

  # REST-fully updates a SubjectSampleSearch
  #
  # @param name [String]
  # PUT  /subject_sample_searches/<subject_sample_search>
  def update
    if @subject_sample_search.update(secure_params)
      flash[:notice] = dt("notices.update", model: @subject_sample_search.name)
    end
    if secure_params.include?('saved')
      respond_with(@subject_sample_search, location: search_subject_sample_searches_url)
    else
      respond_with(@subject_sample_search)
    end
  end

  # REST-fully destroys a SubjectSampleSearch
  #
  # DELETE  /subject_sample_searches/<subject_sample_search>
  def destroy
    @subject_sample_search.destroy
    respond_with(@subject_sample_search, location: subject_sample_searches_url)
  end

  def search
    @subject_sample_search = SubjectSampleSearch.new
  end

  private
    def set_subject_sample_search
      @subject_sample_search = SubjectSampleSearch.find(params[:id])
    end

    def set_user
      @user = current_user
    end
    
    def secure_params
      params.require(:subject_sample_search).permit(:saved, :search, :name, :dna_source, :platform, :stringy_index_ids, :stringy_submitted_ids)
    end

end

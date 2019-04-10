# 7 REST-ful actions on Trio(s)
class TriosController < ApplicationController
  before_action :authenticate_user!
  before_action :set_trio, only: [:show, :edit, :update, :destroy]
  before_action :set_user, only: [:index, :create, :saved, :delete_all, :delete_multiple]

  respond_to :html

  # REST-fully renders all Trio(s)
  #
  # GET /trios
  def index
    @trios = @user.trios.not_saved
    respond_with(@trios)
  end

  def saved
    @trios = @user.trios.saved
    respond_with(@trios)
  end

  def delete_multiple
    @user.trios.saved.where(id: params["trios"]).destroy_all
    redirect_to action: :saved
  end

  def delete_all
    @user.trios.not_saved.destroy_all
    redirect_to action: :index
  end

  # REST-fully renders Trio <trio>
  #
  # GET /trios/<trio>
  def show
    respond_with(@trio) do |format|
      format.html {
        @trio.limited = true
      }
      format.xlsx {
        response.headers['Content-Disposition'] = "'attachment; filename=\"#{@trio.name.parameterize(separator: "_")}.xlsx\""
      }
      format.text {
        send_data render_to_string, filename: @trio.name.parameterize(separator: "_") + '.txt', :disposition => 'attachment', :layout => false
      }
    end
  end

  # REST-fully renders a new unsaved Trio
  #
  # GET /trios/new
  def new
    @trio = Trio.new(name: Time.now.strftime('%d/%m/%Y-%H:%M:%S'), frequency: 0.05, frequency_operator: '<=', impacts: ['high', 'medium'])
    respond_with(@trio)
  end

  # REST-fully renders an editable Trio
  #
  # GET /trios/<trio>/edit
  def edit
  end

  # REST-fully creates a Trio
  #
  # @param name [String]
  # POST /trios
  def create
    @trio = Trio.new(secure_params)
    @trio.user = @user
    if @trio.save
      flash[:notice] = dt("notices.create", :model => @trio.name)
    end
    respond_with(@trio)
  end

  # REST-fully updates a Trio
  #
  # @param name [String]
  # PUT  /trios/<trio>
  def update
    if @trio.update(secure_params)
      flash[:notice] = dt("notices.update", :model => @trio.name)
    end
    if secure_params.include?('saved')
      respond_with(@trio, :location => search_trios_url)
    else
      respond_with(@trio)
    end
  end

  # REST-fully destroys a Trio
  #
  # DELETE  /trios/<trio>
  def destroy
    @trio.destroy
    respond_with(@trio, :location => trios_url)
  end

  def search
    @trio = Trio.new(frequency: 0.05, frequency_operator: '<=', impacts: ['high', 'medium'])
  end

  private
    def set_trio
      @trio = Trio.find(params[:id])
    end

    def set_user
      @user = current_user
    end

    def secure_params
      params.require(:trio).permit(:uploaded_gene_file, :saved, :search, :name,:stringy_gene_ids, :stringy_index_ids, :passing, :frequency, :frequency_operator, :zygosity, :effects => [], :impacts => [], :paths => [])
    end

end

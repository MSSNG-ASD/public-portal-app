class GenesController < ApplicationController
  before_action :authenticate_user!

  respond_to :html

  def show
    @gene = Gene.find_by_gene_id(params[:id])
    respond_with(@gene)
  end

end

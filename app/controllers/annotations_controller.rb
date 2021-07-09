class AnnotationsController < ApplicationController
  before_action :authenticate_user!

  respond_to :html

  def show
    @target_table = params[:source].present? ? params[:source] : nil
    @annotation = Annotation.find(current_user, params[:id], target_table: @target_table)
    if @annotation.nil?
      raise ActiveRecord::RecordNotFound, params[:id]
    else
      respond_with(@annotation)
    end
  end

end

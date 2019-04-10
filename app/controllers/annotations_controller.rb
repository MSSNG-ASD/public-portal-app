class AnnotationsController < ApplicationController
  before_action :authenticate_user!

  respond_to :html

  def show
    @annotation = Annotation.find(current_user, params[:id])
    respond_with(@annotation)
  end

end

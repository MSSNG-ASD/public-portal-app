# Render Help for any <controller>/<action>
class HelpController < ApplicationController
  before_action :authenticate_user!

  # REST-fully renders Help
  #
  # GET /help/<controller>/<action>
  def show
    @controller = params[:controller_id]
    @action = params[:action_id]
  end

end

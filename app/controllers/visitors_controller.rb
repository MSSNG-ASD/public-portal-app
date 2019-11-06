require "./app/helpers/gcp_error_reporting"

class VisitorsController < ApplicationController
  def index
  	redirect_to search_variant_searches_path if user_signed_in?
  end

  def about
  end

  def publications
    render 'pages/publications'
  end

  def change_logs
    render 'pages/change_logs'
  end
end

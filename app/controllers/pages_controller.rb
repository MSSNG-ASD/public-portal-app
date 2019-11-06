class PagesController < ApplicationController
  before_action :authenticate_user!

  def publications
  end

  def acknowledgements
  end
end

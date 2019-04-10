# index, edit, update, show REST-ful actions on User(s)
class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :correct_user?, :except => [:index]

  # REST-fully renders all User(s)
  #
  # GET /users
  def index
    @users = User.all
    authorize User
  end

  # REST-fully renders an editable User
  #
  # GET /users/<user>/edit
  def edit
  end

  # REST-fully updates a User
  #
  # @param name [String]
  # PUT  /users/<user>
  def update
    @user.update_attributes(secure_params)
    # not sure whey I was redirecting to the user's show page before
    # and how this is not redirecting on the production server
    # if @user.update_attributes(secure_params)
    #   redirect_to @user
    # else
    #   render :edit
    # end
  end

  # REST-fully renders User <user>
  #
  # GET /users/<user>
  def show
    authorize @user
  end

  private

  def correct_user?
    @user = User.find(params[:id])
    unless current_user == @user
      redirect_to root_url, :alert => 'Access denied.'
    end
  end

  def secure_params
    params.require(:user).permit(Rails.configuration.x.query['selectable_preferences'].flatten.map {|p| p.to_sym})
  end

end

class ApplicationController < ActionController::Base
  include Pundit
  protect_from_forgery with: :exception

	before_action :revoke_oauth_token, only: :destroy, if: :devise_controller?
  before_action :authorize_bigquery

  helper_method :dt

  protected

  # redirect to variant_searches/index after sign_in
  def after_sign_in_path_for(resource)
    search_variant_searches_path
  end

  private

  # all application actions must have bigquery access
  def authorize_bigquery
    if user_signed_in? && !current_user.credentials.access_token.present?
      reset_session
      redirect_to root_url, alert: "User #{current_user.email} is not authorized for BigQuery access to #{Rails.application.secrets[:project_id]}:mssng_20171020a"
    end
  end

  # revoke oauth token on sign_out
  def revoke_oauth_token
    current_user.revoke_token
  end

  def dt(key, options = {})
    options.merge!(:default => t('app.missing')) unless options.key?(:default)
    t(key, options)
  end

end

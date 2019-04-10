require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Autism
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.1

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # load config/query.yml
    # Rails.configuration.x.query['key']
    config.x.query = config_for(:query)

    config.exceptions_app = ->(env) { ErrorsController.action(:show).call(env) }

    config.google_cloud.project_id = 'example-gcp-project'
    config.google_cloud.use_error_reporting = (ENV['STACKDRIVER_DISABLED'] != '1')
    config.google_cloud.error_reporting.service_name = 'portal-service'
    config.google_cloud.error_reporting.service_version = ENV['DEPLOYMENT_ENVIRONMENT']
    config.google_cloud.error_reporting.ignore_classes = [
      ActionController::BadRequest,
      ActionController::MethodNotAllowed,
      ActionController::RoutingError,
    ]
  end
end

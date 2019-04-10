require 'net/http'
require 'securerandom'
require 'time'


class ErrorsController < ApplicationController
  def show
    error_code = request.path[1..-1]

    @exception = request.env["action_dispatch.exception"]
    backtrace = (@exception.nil? or @exception.backtrace.nil?) ? '(nothing in stack trace)' : @exception.backtrace.join("\n")

    reference_id = SecureRandom.uuid.to_s

    detected_timestamp = Time.now
    human_readable_date = detected_timestamp.strftime "%B %d, %Y"
    human_readable_time = detected_timestamp.strftime "%I:%M:%S %P %Z"

    recipient_email = ENV['SUPPORT_EMAIL_ADDRESS']
    error_email_subject = 'Encountered an unexpected error'
    error_email_body = [
      "While I'm using the portal, the portal has encountered an unexpected error and here is the detail.",
      "Reference ID:\n#{reference_id}",
      "Occurred on:\n#{human_readable_date} at #{human_readable_time}"
    ].join("\n\n")
    error_email_options = URI.encode_www_form({:subject => error_email_subject, :body => error_email_body})

    logger.error "ERROR #{reference_id}: Summary: #{@exception}"
    logger.error "ERROR #{reference_id}: Trace: #{backtrace}"

    contexts = {
      reference_id: reference_id,
      timestamp: detected_timestamp,
      recipient_email: recipient_email,
      error_email_options: error_email_options,
    }

    respond_to do |format|
      format.html { render error_code, layout: 'application', locals: contexts }
      format.json { render json: {status: error_code, error: @exception.message} }
    end
  rescue ActionController::UnknownFormat
    render request.path[1..-1]
  end
end

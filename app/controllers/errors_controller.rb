require 'net/http'
require 'securerandom'
require 'time'


class ErrorsController < ApplicationController
  def show
    @exception = request.env["action_dispatch.exception"]

    error_code = request.path[1..-1]
    overriding_title = nil
    overriding_message = nil
    is_unexpected_error = true

    # Get the stack trace.
    # TODO: Reduce the amount of unrelated backtrackings.
    backtrace_lines = (@exception.nil? or @exception.backtrace.nil?) ? ['(nothing in stack trace)'] : @exception.backtrace
    # rails_root = Rails.root.to_s
    backtrace = backtrace_lines.join("\n")

    # Generate the reference ID.
    reference_id = request.request_id

    # Record the timestamp
    detected_timestamp = Time.now
    human_readable_date = detected_timestamp.strftime "%B %d, %Y"
    human_readable_time = detected_timestamp.strftime "%I:%M:%S %P %Z"

    # Compose a message for the user for self-reporting.
    recipient_email = ENV['SUPPORT_EMAIL_ADDRESS']
    error_email_subject = 'Encountered an unexpected error'
    error_email_body = [
      "While I'm using the portal, the portal has encountered an unexpected error and here is the detail.",
      "Reference ID:\n#{reference_id}",
      "Occurred on:\n#{human_readable_date} at #{human_readable_time}"
    ].join("\n\n")
    error_email_options = URI.encode_www_form({:subject => error_email_subject, :body => error_email_body})

    # Put the error information in the log
    logger.error "REQUEST #{reference_id}: Status: #{error_code}"
    logger.error "REQUEST #{reference_id}: Class: #{@exception.nil? ? 'Unknown Class' : @exception.class}"
    logger.error "REQUEST #{reference_id}: Message: #{@exception}"
    logger.error "REQUEST #{reference_id}: Trace: \n#{backtrace}"

    # Check if the error is critical.
    # NOTE: When the service experience a critical error, the auto-shutdown may be triggered.
    @is_critical = false

    if @exception.class == NoMemoryError
      @is_critical = true
      logger.error "REQUEST #{reference_id}: Critical Error Detected"

      t = Thread.new do
        logger.warn "REQUEST #{reference_id}: Self-restart will be initiated in 15 seconds."
        sleep 15
        logger.warn "REQUEST #{reference_id}: Initiated the process kill"
        `pkill ruby`
      end
    elsif @exception.class == BigQuery::QueryError and @exception.message.match(/^Access Denied: /)
      is_unexpected_error = false
      overriding_title = 'Unexpected Access Denial'
      overriding_message = 'Apparently, you do not have permission to access to the data. Please contact us for further assistance.'
    end

    # Render the error.
    contexts = {
      reference_id:        reference_id,
      timestamp:           detected_timestamp,
      recipient_email:     recipient_email,
      error_email_options: error_email_options,
      error_code:          error_code,
      overriding_title:    overriding_title,
      overriding_message:  overriding_message,
      is_unexpected_error: is_unexpected_error,
    }

    respond_to do |format|
      format.html { render error_code, layout: 'application', locals: contexts }
      format.json { render json: {status: error_code, error: @exception.message} }
    end
  rescue ActionController::UnknownFormat
    render request.path[1..-1]
  end
end

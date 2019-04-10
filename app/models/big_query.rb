class BigQuery

  ##
  # Raised when a query fails for any reason.
  class SqlFailedError < StandardError
    def initialize(message)
      super(message)
    end
  end

  class AmbiguousQueryJobError < StandardError
    def initialize(message)
      super(message)
    end
  end

  attr_accessor :credentials, :table, :primary_key

  # only authenticated users that can perform a simple query are authorized
  def self.authorized_token?(token, refresh_token, expires_at)
    # this will error if unauthorized
    begin
      credentials = Google::Auth::UserRefreshCredentials.new(
        client_id: Rails.application.secrets[:google_client_id],
        client_secret: Rails.application.secrets[:google_secret],
        scope: Rails.configuration.x.query['scope'],
        access_token: token,
        refresh_token: refresh_token,
        expires_at: expires_at
      )
      bigquery = Google::Cloud::Bigquery.new(
        project_id: Rails.configuration.x.query['project_id'],
        credentials: credentials,
        scope: Rails.configuration.x.query['scope']
      )
      bigquery.query "select indexid from `#{Rails.configuration.x.query['dataset_id']}.subject` limit 1"
    # permission denied
    rescue Google::Cloud::PermissionDeniedError => e
      return false
    # return true if no exceptions
    else
      return true
    end
    # return false with any uncaught exceptions
    false
  end

  # initialize with current user oauth credentials
  def initialize(credentials)
    @credentials = credentials
  end

  def exec_query(sql)
    bq = Google::Cloud::Bigquery.new(
      project_id: Rails.configuration.x.query['project_id'],
      credentials: credentials,
      scope: Rails.configuration.x.query['scope']
    )
    begin
      job = bq.query_job sql
    rescue Google::Cloud::InvalidArgumentError => e
      if e.message.match? /invalid: The query is too large./
        raise AmbiguousQueryJobError, "Either the query or the result set is too large. We are currently investigating this issue. If possible, please contact us with the details on how you use the portal before encounter this error. (Original: #{e.message.gsub(/invalid: /, '')})"
      else
        raise SqlFailedError, e.message
      end
    rescue
      raise SqlFailedError, e.message
    end
    job.wait_until_done!
    if job.failed?
      raise SqlFailedError.new(job.status['errorResult']['message'])
    else
      job.data.all.to_a
    end
  end

end

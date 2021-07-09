class BigQuery

  ##
  # Raised when a query fails for any reason.
  class QueryError < StandardError
    def initialize(message)
      super(message)
    end
  end

  class Job
    def initialize(bq_job)
      @bq_job = bq_job
    end

    def id
      @bq_job.job_id
    end

    def all
      @bq_job.data.all.to_a
    end

    def stat
      # NOTE: job.statistics will return something like this:
      # {
      #   "creationTime"        => "1562856807364",
      #   "endTime"             => "1562856807781",
      #   "startTime"           => "1562856807757",
      #   "totalBytesProcessed" => "0",
      #   "query"               => {
      #     "cacheHit"            => true,
      #     "statementType"       => "SELECT",
      #     "totalBytesBilled"    => "0",
      #     "totalBytesProcessed" => "0"
      #   },
      # }
      @bq_job.statistics
    end
  end

  class NoResult
    # This is a proxy object used when there is no result. It is designed to have the same interface as Job but not a subclass of it.
    def initialize(job)
      @job = job
      @dummy_list = []
    end

    def id
      @job.id
    end

    def all
      @dummy_list
    end

    def stat
      # The structure is the same as Job.
      @job.stat
    end
  end

  class LengthLimitExceededError < QueryError
  end

  class InitializationError < QueryError
  end

  class PossibleExecutionTimeoutError < QueryError
  end

  class ExecutionError < QueryError
  end

  attr_accessor :credentials, :table, :primary_key

  # only authenticated users that can perform a simple query are authorized
  def self.authorized_token?(token, refresh_token, expires_at)
    # this will error if unauthorized
    query_config = Rails.configuration.x.query
    login_scope = query_config['scope']
    db6_config = query_config['db6']

    if query_config['project_id'].nil? or query_config['project_id'].empty?
      raise RuntimeError, "The service is not configured properly."
    end

    begin
      credentials = Google::Auth::UserRefreshCredentials.new(
        client_id: Rails.application.secrets[:google_client_id],
        client_secret: Rails.application.secrets[:google_secret],
        scope: login_scope,
        access_token: token,
        refresh_token: refresh_token,
        expires_at: expires_at,
      )
      bq = Google::Cloud::Bigquery.new(
        project_id: query_config['project_id'],
        credentials: credentials,
        scope: login_scope,
      )
      test_sql = "SELECT indexid FROM `#{db6_config['project_id']}.#{db6_config['tables']['subjects']}` LIMIT 1"
      bq.query test_sql
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
    query_config = Rails.configuration.x.query
    config = query_config['db6']

    bq = Google::Cloud::Bigquery.new(
      project_id: query_config['project_id'],
      credentials: credentials,
      scope: Rails.configuration.x.query['scope']
    )

    begin
      job = bq.query_job sql
    rescue Google::Cloud::InvalidArgumentError => e
      if e.message.match? /invalid: The query is too large./
        raise LengthLimitExceededError, "Detected unoptimized query (#{e.message})"
      else
        raise InitializationError, "Failed to initiate the query (#{e.message})"
      end
    end
    begin
      job.wait_until_done!
    rescue Google::Cloud::Error => e
      if e.message.match? /execution expired/
        raise PossibleExecutionTimeoutError, "Possible execution timeout (#{e.message})"
      else
        raise ExecutionError, "Unexpected error occured during query execution (#{e.message})"
      end
    end

    if job.failed?
      lines = []
      sql.split(/\n/).each_with_index do |line, line_number|
        lines << ("%4.4s: %s" % [line_number + 1, line])
      end
      puts "ERROR OCCURRED WHILE EXECUTING BIGQUERY QUERY:\n#{job.status['errorResult']['message']}\n----------\n#{lines.join("\n")}\n----------"
      raise QueryError, job.status['errorResult']['message']
    end

    Job.new(job)
  end

end

require 'securerandom'
require 'time'

class Search < ApplicationRecord
  belongs_to :user
  validates :name, presence: true, length: { maximum: 255 }
  default_scope { order("created_at DESC") }

  scope :saved, -> { where(saved: true) }
  scope :not_saved, -> { where(saved: nil) }

  def save_job_stat(user_id, job_group_id, job)
    raw_stat = job.stat

    BigQueryJobStat.create(
      id: SecureRandom.uuid,
      user_id: user_id,
      job_group_id: job_group_id,
      created_at: raw_stat["creationTime"].to_i,
      ended_at: raw_stat["endTime"].to_i,
      recorded_at: Time.now.utc,
      started_at: raw_stat["startTime"].to_i,
      query_cache: raw_stat["query"]["cacheHit"] ? 'hit' : 'missed',
      query_total_bytes_billed: raw_stat["query"]["totalBytesBilled"].to_i,
      query_total_bytes_processed: raw_stat["query"]["totalBytesProcessed"].to_i,
    )
  end
end

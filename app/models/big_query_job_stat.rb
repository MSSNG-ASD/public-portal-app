class BigQueryJobStat < ApplicationRecord
  self.table_name = 'BigQueryJobStats'

  validates :user_id,                     presence: true
  validates :job_group_id,                presence: true
  validates :created_at,                  presence: true
  validates :ended_at,                    presence: true
  validates :recorded_at,                 presence: true
  validates :started_at,                  presence: true
  validates :query_cache,                 presence: true
  validates :query_total_bytes_billed,    presence: true
  validates :query_total_bytes_processed, presence: true
end
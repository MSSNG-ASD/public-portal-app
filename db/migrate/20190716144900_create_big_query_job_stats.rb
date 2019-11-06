class CreateBigQueryJobStats < ActiveRecord::Migration[5.1]
  def change
    create_table :BigQueryJobStats, id: 'CHAR(36)' do |t|
      t.string :user_id,  null: false
      t.string :job_group_id,  null: false  # expected: request ID or primary job ID
      t.bigint :created_at,  null: false
      t.bigint :ended_at,  null: false
      t.datetime :recorded_at,  null: false  # When the stat is record
      t.bigint :started_at,  null: false
      t.string :query_cache,  null: false
      t.bigint :query_total_bytes_billed,  null: false
      t.bigint :query_total_bytes_processed,  null: false
    end

    add_index :BigQueryJobStats, :user_id
    add_index :BigQueryJobStats, [:user_id, :job_group_id]
  end
end
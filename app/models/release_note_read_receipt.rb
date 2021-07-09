class ReleaseNoteReadReceipt < ApplicationRecord
  self.table_name = 'ReleaseNoteReadReceipts'

  validates :user_id, presence: true
  validates :entry_id, presence: true
  validates :created_at, presence: true
end
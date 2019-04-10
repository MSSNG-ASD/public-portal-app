class Search < ApplicationRecord
  belongs_to :user
  validates :name, presence: true, length: { maximum: 255 }
  default_scope { order("created_at DESC") }

  scope :saved, -> { where(saved: true) }
  scope :not_saved, -> { where(saved: nil) }
end

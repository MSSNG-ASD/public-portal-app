class CreateReleaseNoteReadReceipts < ActiveRecord::Migration[5.1]
  def change
    create_table :ReleaseNoteReadReceipts, id: 'CHAR(36)' do |t|
      t.string :user_id,  null: false
      t.string :entry_id, null: false
      t.datetime :created_at
    end

    add_index :ReleaseNoteReadReceipts, :user_id
    add_index :ReleaseNoteReadReceipts, [:user_id, :entry_id], unique: true
    add_index :ReleaseNoteReadReceipts, :created_at
  end
end
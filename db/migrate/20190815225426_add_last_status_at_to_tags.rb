class AddLastStatusAtToTags < ActiveRecord::Migration[5.2]
  def change
    change_table :tags, bulk: true do |t|
      t.column :last_status_at, :datetime
      t.column :last_trend_at, :datetime
    end
  end
end

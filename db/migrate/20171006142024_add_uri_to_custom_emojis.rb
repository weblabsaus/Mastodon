class AddUriToCustomEmojis < ActiveRecord::Migration[5.2]
  def change
    change_table :custom_emojis, bulk: true do |t|
      t.column :uri, :string
      t.column :image_remote_url, :string
    end
  end
end

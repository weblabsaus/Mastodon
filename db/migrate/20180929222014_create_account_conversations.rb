class CreateAccountConversations < ActiveRecord::Migration[5.2]
  def change
    create_table :account_conversations do |t|
      t.belongs_to :account, foreign_key: { on_delete: :cascade }
      t.belongs_to :conversation, foreign_key: { on_delete: :cascade }
      t.bigint :participant_account_ids, array: true, null: false, default: []
      t.bigint :status_ids, array: true, null: false, default: []
      t.bigint :last_status_id, null: true, default: nil
    end

    add_index :account_conversations, [:account_id, :conversation_id, :participant_account_ids], unique: true, name: 'index_unique_conversations'
  end
end

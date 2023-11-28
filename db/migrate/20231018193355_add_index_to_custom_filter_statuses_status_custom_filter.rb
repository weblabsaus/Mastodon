# frozen_string_literal: true

class AddIndexToCustomFilterStatusesStatusCustomFilter < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    deduplicate_records
    add_index_to_table
  end

  def down
    remove_index_from_table
  end

  private

  def add_index_to_table
    add_index :custom_filter_statuses, [:status_id, :custom_filter_id], unique: true, algorithm: :concurrently
  end

  def remove_index_from_table
    remove_index :custom_filter_statuses, [:status_id, :custom_filter_id]
  end

  def deduplicate_records
    safety_assured do
      execute <<~SQL.squish
        DELETE FROM custom_filter_statuses
          WHERE id NOT IN (
          SELECT DISTINCT ON(status_id, custom_filter_id) id FROM custom_filter_statuses
          ORDER BY status_id, custom_filter_id, id ASC
        )
      SQL
    end
  end
end

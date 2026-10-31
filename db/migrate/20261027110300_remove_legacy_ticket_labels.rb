class RemoveLegacyTicketLabels < ActiveRecord::Migration[8.1]
  def up
    # The column remains as a private, stable audit key, but the old TR-/LM-
    # ticket convention is removed from existing records as well as new ones.
    execute "UPDATE tours SET reference_no = 'record-' || id::text"
    execute <<~SQL.squish
      UPDATE notifications
      SET title = regexp_replace(title, '(TR|LM)-[0-9]{4}-[0-9]{6}', 'tour record', 'g'),
          body = regexp_replace(body, '(TR|LM)-[0-9]{4}-[0-9]{6}', 'tour record', 'g')
      WHERE title ~ '(TR|LM)-[0-9]{4}-[0-9]{6}'
         OR body ~ '(TR|LM)-[0-9]{4}-[0-9]{6}'
    SQL
  end

  def down
    # The former ticket labels intentionally cannot be reconstructed.
  end
end

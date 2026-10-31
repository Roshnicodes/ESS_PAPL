# Applies the approved special-travel routes to the existing master without
# disturbing notify-only users already configured for a mode.
class ConfigureSpecialTravelApprovals < ActiveRecord::Migration[8.1]
  def up
    coo_id = select_value(<<~SQL.squish)
      SELECT id FROM users
      WHERE active = true AND lower(trim(designation)) = 'coo'
      ORDER BY id LIMIT 1
    SQL
    director_id = select_value(<<~SQL.squish)
      SELECT id FROM users
      WHERE active = true AND lower(trim(designation)) = 'director'
      ORDER BY id LIMIT 1
    SQL

    vande_bharat_id = select_value("SELECT id FROM travel_modes WHERE lower(name) = 'vande bharat train' LIMIT 1")
    unless vande_bharat_id
      execute <<~SQL
        INSERT INTO travel_modes (name, category, km_based, manual_total, for_tour_plan, for_city_travel, for_local_travel, position, active, is_train, created_at, updated_at)
        VALUES ('Vande Bharat Train', 'public', false, false, true, true, false,
                (SELECT COALESCE(MAX(position), 0) + 1 FROM travel_modes), true, true, NOW(), NOW())
      SQL
    end

    execute "UPDATE travel_modes SET is_train = true, updated_at = NOW() WHERE name ILIKE 'Train(%' OR name = 'Vande Bharat Train'"

    routes = {
      "Personal Four Wheeler" => [ coo_id, director_id ],
      "Train(3A)" => [ coo_id ],
      "Train(2A)" => [ coo_id ],
      "Train(1A)" => [ director_id ],
      "Flight" => [ director_id ],
      "Vande Bharat Train" => [ coo_id ]
    }

    routes.each do |name, approvers|
      next if approvers.any?(&:blank?)

      mode_id = select_value("SELECT id FROM travel_modes WHERE lower(name) = #{connection.quote(name.downcase)} LIMIT 1")
      next unless mode_id

      execute "DELETE FROM travel_mode_approvers WHERE travel_mode_id = #{mode_id} AND kind = 'approve'"
      approvers.each_with_index do |user_id, index|
        execute <<~SQL
          INSERT INTO travel_mode_approvers (travel_mode_id, user_id, kind, position, created_at, updated_at)
          VALUES (#{mode_id}, #{user_id}, 'approve', #{index + 1}, NOW(), NOW())
        SQL
      end
    end

    return unless coo_id

    select_values("SELECT id FROM travel_modes WHERE is_train = true").each do |mode_id|
      execute "DELETE FROM travel_mode_approvers WHERE travel_mode_id = #{mode_id} AND kind = 'tatkal'"
      execute <<~SQL
        INSERT INTO travel_mode_approvers (travel_mode_id, user_id, kind, position, created_at, updated_at)
        VALUES (#{mode_id}, #{coo_id}, 'tatkal', 1, NOW(), NOW())
      SQL
    end
  end
end

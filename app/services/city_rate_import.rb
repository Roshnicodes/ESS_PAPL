require "roo"

# Upload of the City & DA rate sheet (.xlsx / .csv) – one transaction, all cities loaded once.
#   City found (any case)  → DA rate / State / Active updated from the sheet (blank cell = keep)
#   City not found         → added (DA rate required)
class CityRateImport
  HEADERS = {
    name:         [ "city", "city name", "city_name", "name" ],
    state:        [ "state" ],
    da_rate:      [ "rate (da & lodging)", "rate", "da rate", "da", "da_rate", "daily allowance", "da & lodging rate" ],
    active:       [ "active", "status", "enabled" ]
  }.freeze

  Result = Struct.new(:created, :updated, :unchanged, :errors, keyword_init: true)

  def initialize(path, by:, original_filename: nil)
    @path, @by = path, by
    @ext = File.extname(original_filename || path).delete(".").downcase.presence || "xlsx"
  end

  def call
    sheet = Roo::Spreadsheet.open(@path, extension: @ext.to_sym).sheet(0)
    header_row = (1..[ sheet.last_row.to_i, 10 ].min).find { |r| column_map(sheet.row(r)).key?(:name) }
    raise ArgumentError, "No “City” column found in the sheet" unless header_row
    cols = column_map(sheet.row(header_row))
    res = Result.new(created: 0, updated: 0, unchanged: 0, errors: [])
    cities = City.all.index_by { |c| c.name.downcase.squish }

    City.transaction do
      ((header_row + 1)..sheet.last_row.to_i).each do |r|
        row = sheet.row(r)
        name = row[cols[:name]].to_s.gsub(/\[\d+\]/, "").squish
        next if name.blank?
        city = cities[name.downcase] || City.new(name: name, active: true)
        attrs = {}
        attrs[:state]        = row[cols[:state]].to_s.squish.presence if cols[:state] && row[cols[:state]].present?
        attrs[:da_rate]      = money(row[cols[:da_rate]]) if cols[:da_rate] && row[cols[:da_rate]].present?
        attrs[:active]       = !row[cols[:active]].to_s.strip.downcase.in?(%w[no n false 0 disabled inactive]) if cols[:active] && row[cols[:active]].present?
        city.assign_attributes(attrs)
        unless city.new_record? || city.changed?
          res.unchanged += 1
          next
        end
        new_city = city.new_record?
        changes = city.changes.except("updated_at", "created_at").transform_values { |v| v.map(&:to_s) }
        if city.save
          city.log_activity!(new_city ? :city_added : :city_updated, actor: @by, details: changes.merge(source: "excel", line: r))
          new_city ? res.created += 1 : res.updated += 1
          cities[name.downcase] = city
        else
          res.errors << "Row #{r} (#{name}): #{city.errors.full_messages.to_sentence}"
        end
      end
    end
    res
  end

  private

  def column_map(row)
    heads = row.map { |h| h.to_s.strip.downcase.squish }
    HEADERS.each_with_object({}) do |(key, names), map|
      idx = heads.index { |h| names.include?(h) }
      map[key] = idx if idx
    end
  end

  def money(value)
    value.to_s.gsub(/[₹,\s]/, "").to_d.round(2)
  end
end

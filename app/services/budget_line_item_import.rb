require "csv"

# Imports the finance coding sheet supplied by accounts:
#   BLI_Name, BLI Code, Project_Name
#
# Every row creates a project → BLI → code relationship.  The master records
# remain reusable, while the relationship is what drives the dependent finance
# approval dropdowns.
class BudgetLineItemImport
  Result = Struct.new(:created, :existing, :projects, :line_items, :codes, :errors, keyword_init: true)

  HEADER_ALIASES = {
    project: [ "project_name", "project name", "project" ],
    line_item: [ "bli_name", "bli name", "budget line item", "budget line item name" ],
    code: [ "bli_code", "bli code", "budget line item code", "code" ]
  }.freeze

  def initialize(path, by:)
    @path = path
    @by = by
  end

  def call
    rows = CSV.read(@path, headers: true, encoding: "bom|utf-8")
    columns = header_columns(rows.headers)
    missing = HEADER_ALIASES.keys - columns.keys
    raise ArgumentError, "CSV must include Project_Name, BLI_Name and BLI Code columns" if missing.any?

    result = Result.new(created: 0, existing: 0, projects: 0, line_items: 0, codes: 0, errors: [])

    ProjectBudgetLineItem.transaction do
      rows.each_with_index do |row, index|
        values = columns.transform_values { |header| clean(row[header]) }
        next if values.values.all?(&:blank?)

        if values.values.any?(&:blank?)
          result.errors << "Row #{index + 2}: Project, BLI name and BLI code are all required."
          next
        end

        import_row!(values, result)
      rescue ActiveRecord::RecordInvalid => e
        result.errors << "Row #{index + 2}: #{e.record.errors.full_messages.to_sentence}"
      end
    end

    result
  rescue CSV::MalformedCSVError => e
    raise ArgumentError, "Could not read the CSV: #{e.message}"
  end

  private

  def header_columns(headers)
    normalized = headers.each_with_object({}) { |header, out| out[normalise_header(header)] = header }
    HEADER_ALIASES.each_with_object({}) do |(key, aliases), out|
      out[key] = aliases.lazy.map { |name| normalized[normalise_header(name)] }.find(&:present?)
    end.compact
  end

  def import_row!(values, result)
    project, new_project = find_or_create(Project, values[:project])
    line_item, new_line_item = find_or_create(BudgetLineItem, values[:line_item])
    code, new_code = find_or_create(BudgetLineItemCode, values[:code])

    mapping = ProjectBudgetLineItem.find_or_initialize_by(
      project: project, budget_line_item: line_item, budget_line_item_code: code
    )
    if mapping.new_record?
      mapping.created_by = @by
      mapping.active = true
      mapping.save!
      result.created += 1
    elsif !mapping.active?
      mapping.update!(active: true)
      result.created += 1
    else
      result.existing += 1
    end

    result.projects += 1 if new_project
    result.line_items += 1 if new_line_item
    result.codes += 1 if new_code
  end

  def find_or_create(klass, value)
    existing = klass.where("lower(name) = ?", value.downcase).first
    return [ existing, false ] if existing

    [ klass.create!(name: value, created_by: @by), true ]
  rescue ActiveRecord::RecordNotUnique
    [ klass.where("lower(name) = ?", value.downcase).first!, false ]
  end

  def normalise_header(value)
    value.to_s.delete_prefix("\uFEFF").tr("_", " ").squish.downcase
  end

  def clean(value)
    value.to_s.delete_prefix("\uFEFF").squish.presence
  end
end

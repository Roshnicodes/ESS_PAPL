# One search box for the lists: every word typed must appear somewhere in the row (name, code, place, …).
# Searches run as "id IN (subquery)", so they also work on scopes built with .or() chains.
module ListSearch
  extend ActiveSupport::Concern

  included do
    helper_method :search_query if respond_to?(:helper_method)
  end

  # employee name / code / designation / location, the tour (reference, description, visit places)
  # and the claim (description, UTR, status)
  CLAIM_SQL = <<~SQL.squish.freeze
    concat_ws(' ', u.name, u.emp_code, u.designation, l.name, t.reference_no, t.general_description,
      to_char(t.claim_month, 'Mon-YYYY'), c.general_description, c.utr_no, replace(c.status, '_', ' '),
      (SELECT string_agg(v.place, ' ') FROM tour_visits v WHERE v.tour_id = t.id))
  SQL
  TOUR_SQL = <<~SQL.squish.freeze
    concat_ws(' ', u.name, u.emp_code, u.designation, l.name, t.reference_no, t.general_description,
      to_char(t.claim_month, 'Mon-YYYY'), replace(t.status, '_', ' '),
      (SELECT string_agg(v.place, ' ') FROM tour_visits v WHERE v.tour_id = t.id))
  SQL

  def search_query = params[:q].to_s.squish.presence

  def search_claims(scope)
    each_word(scope) do |s, like|
      s.where(id: TourClaim.unscoped.from("tour_claims c").select("c.id")
                .joins("JOIN tours t ON t.id = c.tour_id JOIN users u ON u.id = c.user_id LEFT JOIN locations l ON l.id = u.location_id")
                .where("#{CLAIM_SQL} ILIKE ?", like))
    end
  end

  def search_tours(scope)
    each_word(scope) do |s, like|
      s.where(id: Tour.unscoped.from("tours t").select("t.id")
                .joins("JOIN users u ON u.id = t.user_id LEFT JOIN locations l ON l.id = u.location_id")
                .where("#{TOUR_SQL} ILIKE ?", like))
    end
  end

  # plain columns of the scope's own table, e.g. search_columns(scope, %w[circulars.topic circulars.description])
  def search_columns(scope, columns)
    each_word(scope) { |s, like| s.where("concat_ws(' ', #{columns.join(', ')}) ILIKE ?", like) }
  end

  private

  def each_word(scope)
    return scope unless search_query
    search_query.split.first(6).reduce(scope) { |s, word| yield(s, "%#{ActiveRecord::Base.sanitize_sql_like(word)}%") }
  end
end

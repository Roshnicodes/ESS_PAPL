# Live ESS strips funder / project names from free-text descriptions ("A prohibited word has been
# found and removed") – project coding is PD Finance's job. Blocked list = active Project names + "PAPL".
module BlockedWords
  extend ActiveSupport::Concern

  EXTRA = %w[PAPL].freeze

  class_methods do
    def strip_blocked_words_from(*attrs)
      before_validation do
        attrs.each do |attr|
          cleaned, hit = BlockedWords.clean(self[attr])
          next unless hit
          self[attr] = cleaned
          (@blocked_words_removed ||= []) << attr
        end
      end
    end
  end

  def blocked_words_removed? = @blocked_words_removed.present?

  def self.list
    load = proc { (Project.active.pluck(:name) + EXTRA).uniq.sort_by { -_1.length } }
    Rails.cache.fetch("blocked_words/#{Project.maximum(:updated_at).to_i}", expires_in: 10.minutes, &load)
  rescue ActiveRecord::ActiveRecordError => e   # cache database down / missing – work without the cache
    Rails.logger.error("BlockedWords cache unavailable: #{e.class} #{e.message}")
    load.call
  end

  def self.regex
    Regexp.new(list.map { |w| "(?<![[:alnum:]])#{Regexp.escape(w)}(?![[:alnum:]])" }.join("|"), Regexp::IGNORECASE)
  end

  # => [cleaned_text, removed_anything?]
  def self.clean(text)
    return [ text, false ] if text.blank?
    cleaned = text.gsub(regex, "").gsub(/[ \t]{2,}/, " ").strip
    [ cleaned, cleaned != text.strip ]
  end
end

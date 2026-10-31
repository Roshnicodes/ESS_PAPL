# Sends one notification mail through krai. Runs inside the web process (:async), so no separate
# job worker is needed on the server; a failed mail is only logged.
class EssMailJob < ApplicationJob
  self.queue_adapter = :async unless Rails.env.test?

  def perform(params)
    EssMailRelay.deliver!(params)
  rescue StandardError => error
    Rails.logger.error("EssMailRelay failed type=#{params['mail_type']} to=#{params['to_email']}: #{error.class} #{error.message}")
  end
end

# Sends the bell + email notification of one IOM / Circular to its audience.
# Runs in the web process (:async, like EssMailJob) so the admin's Save returns at once
# even when the circular goes to every employee.
class CircularNotifyJob < ApplicationJob
  self.queue_adapter = :async unless Rails.env.test?

  def perform(circular_id, actor_id = nil)
    circular = Circular.find_by(id: circular_id) or return
    circular.notify!(by: User.find_by(id: actor_id) || circular.created_by)
  rescue StandardError => error
    Rails.logger.error("CircularNotifyJob failed circular=#{circular_id}: #{error.class} #{error.message}")
  end
end

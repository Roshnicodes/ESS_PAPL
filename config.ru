# This file is used by Rack-based servers to start the application.

require_relative "config/environment"

# Served under a sub-path (RAILS_RELATIVE_URL_ROOT=/papl → https://hr.asaindia.org/papl). Works whether nginx
# passes the prefix on (/papl/users/sign_in) or strips it (/users/sign_in): the router always sees the path
# without it, and SCRIPT_NAME=/papl makes every generated link, form and redirect carry /papl again.
root = Rails.application.config.relative_url_root.to_s.chomp("/")

if root.empty?
  run Rails.application
else
  run lambda { |env|
    path = env["PATH_INFO"].to_s
    env["PATH_INFO"] = path.delete_prefix(root).presence || "/" if path == root || path.start_with?("#{root}/")
    env["SCRIPT_NAME"] = root
    Rails.application.call(env)
  }
end
Rails.application.load_server

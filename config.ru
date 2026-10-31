# This file is used by Rack-based servers to start the application.

require_relative "config/environment"

# Served under a sub-path (RAILS_RELATIVE_URL_ROOT=/papl → https://hr.asaindia.org/papl): Rack strips the prefix
# for the router and sets SCRIPT_NAME, so every generated link, form and redirect carries /papl again.
map Rails.application.config.relative_url_root.presence || "/" do
  run Rails.application
end
Rails.application.load_server

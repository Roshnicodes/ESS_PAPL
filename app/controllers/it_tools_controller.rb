# IT Tools menu: sends the logged-in employee to Guest House / Help Desk / Training / GeoHub already signed in.
class ItToolsController < ApplicationController
  def open
    key = params[:tool].to_s
    return redirect_to(authenticated_root_path, alert: "Unknown tool.") unless ExternalAppLink.tool?(key)

    url = ExternalAppLink.url_for(key, current_user)
    return redirect_to(authenticated_root_path, alert: "#{ExternalAppLink.label(key)} is not connected yet – please contact IT.") unless url

    current_user.log_activity!(:it_tool_opened, details: { tool: key }) if current_user.respond_to?(:log_activity!)
    redirect_to url, allow_other_host: true
  end
end

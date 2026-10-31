# Mark invalid inputs with a red border instead of wrapping them in <div class="field_with_errors"> (keeps grid layouts intact).
ActionView::Base.field_error_proc = proc do |html_tag, _instance|
  if html_tag =~ /<(input|select|textarea)/
    html_tag.sub(/class="/, 'class="field-error ').then { |t| t.include?("field-error") ? t : t.sub(/<(input|select|textarea)/, '<\1 class="field-error"') }.html_safe
  else
    html_tag
  end
end

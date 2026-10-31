module Workflow
  class Error < StandardError; end
  class NotAllowed < Error; end
  class RemarkRequired < Error
    def initialize(msg = "Remark is required") = super
  end
end

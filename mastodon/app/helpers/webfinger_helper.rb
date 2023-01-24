# frozen_string_literal: true

module WebfingerHelper
  def webfinger!(uri)
    Rails.logger.debug "Webfingering #{uri}"
    Webfinger.new(uri).perform
  end
end

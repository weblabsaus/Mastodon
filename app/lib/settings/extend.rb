module Settings
  module Extend
    def settings
      @settings ||= ScopedSettings.new(self)
    end
  end
end

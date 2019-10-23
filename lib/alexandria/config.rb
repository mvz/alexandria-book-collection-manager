# frozen_string_literal: true

module Alexandria
  module Config
    SHARE_DIR = File.expand_path("../../share", File.dirname(__FILE__))
    SOUNDS_DIR = "#{SHARE_DIR}/sounds/alexandria"
    DATA_DIR = "#{SHARE_DIR}/alexandria"
    MAIN_DATA_DIR = DATA_DIR
  end
end

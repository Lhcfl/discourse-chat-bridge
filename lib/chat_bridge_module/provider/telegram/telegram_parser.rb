# frozen_string_literal: true

module ::ChatBridgeModule
  module Provider
    module TelegramBridge
      def self.make_display_name(tg_user)
        if tg_user["last_name"].present?
          "#{tg_user["first_name"]} #{tg_user["last_name"]}"
        else
          "#{tg_user["first_name"]}"
        end
      end
    end
  end
end

require_relative "parsers/parser"
require_relative "parsers/tghtml"
require_relative "parsers/make_discourse_message"

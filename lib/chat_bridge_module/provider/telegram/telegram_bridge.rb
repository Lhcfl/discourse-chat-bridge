# frozen_string_literal: true

module ::ChatBridgeModule
  module Provider
    module TelegramBridge
      PROVIDER_ID = 1
      PROVIDER_SLUG = "Telegram".freeze
    end
  end
end

require_relative "telegram_initializer"
require_relative "telegram_lib"
require_relative "telegram_utils"
require_relative "telegram_parser"
require_relative "telegram_message_helper"

require_relative "services/handle_discourse_message"
require_relative "services/handle_tg_message"

module ::ChatBridgeModule::Provider::TelegramBridge
  # Telegram  ---> Discourse
  %i[message edited_message].each do |event|
    ::ChatBridgeModule::Provider::TelegramBridge::TelegramEvent.on(event) do |message|
      Scheduler::Defer.later("Bridge a telegram #{event} to discourse") do
        result =
          ::ChatBridgeModule::Provider::TelegramBridge::HandleTgMessage.call(
            message:,
            edit: event == :edited_message,
          )

        if result.failure?
          Rails.logger.warn(
            "[Telegram Bridge] Failed to bridge message: \n" +
              "#{result.inspect_steps.error}\n#{result.inspect_steps.inspect}\n" + "----------\n" +
              "In message:\n" + "#{result.message_instance.to_json}\n" +
              if result.message_to_edit
                "----------\n" + "Message to edit:\n" + "#{result.message_to_edit.to_json}\n"
              else
                "\n"
              end,
          )
        end
      end
    end
  end

  # Discourse ---> Telegram
  %i[chat_message_created chat_message_edited chat_message_trashed].each do |event|
    DiscourseEvent.on(event) do |message, channel, user|
      Scheduler::Defer.later("Bridge #{event} to telegram") do
        result =
          ::ChatBridgeModule::Provider::TelegramBridge::HandleDiscourseMessage.call(
            message:,
            channel:,
            user:,
            event:,
          )
        if result.failure? && !(%w[BRIDGE_BACK INVALID_BOT].include? result.inspect_steps.error)
          Rails.logger.warn(
            "[Discourse -> Telegram] Failed in #{event}: \n#{result.inspect_steps.inspect}\n#{result.inspect_steps.error} \n----------\nIn message: #{message.to_json}",
          )
        end
      end
    end
  end
end

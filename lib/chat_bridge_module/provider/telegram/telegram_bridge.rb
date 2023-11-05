# frozen_string_literal: true

require_relative "telegram_initializer"
require_relative "telegram_lib"
require_relative "telegram_utils"
require_relative "telegram_parser"

module ::ChatBridgeModule
  module Provider
    module TelegramBridge
      PROVIDER_ID = 1
      PROVIDER_SLUG = "Telegram".freeze

      def self.handleTgMessage(message)
        channel_id =
          ::ChatBridgeModule::Provider::TelegramBridge.getChannelId? message["chat"]["id"]

        if channel_id.nil?
          return(
            Rails.logger.warn(
              "[Telegram Bridge] Received a telegram message but no channel id found. details: #{JSON.dump(message)}",
            )
          )
        end
        if message["from"].nil?
          return(
            Rails.logger.warn(
              "[Telegram Bridge] Received a telegram message but no message.from found. details: #{JSON.dump(message)}",
            )
          )
        end
        if message["from"]["id"].nil?
          return(
            Rails.logger.warn(
              "[Telegram Bridge] Received a telegram message but no message.from.id found. details: #{JSON.dump(message)}",
            )
          )
        end

        fake_user =
          ::ChatBridgeModule::FakeUser::ChatBridgeFakeUser.get_or_create(
            ::ChatBridgeModule::Provider::TelegramBridge::PROVIDER_ID,
            message["from"]["id"].to_i,
            ::ChatBridgeModule::Provider::TelegramBridge::PROVIDER_SLUG,
            "#{message["from"]["id"]}.tgid",
          )

        creator =
          ::ChatBridgeModule::CreateMessage.call(
            chat_channel_id: channel_id,
            guardian: ::ChatBridgeModule::GhostUserGuardian.new(fake_user.user),
            message:
              ::ChatBridgeModule::Provider::TelegramBridge.make_markdown_from_message(message) ||
                "[一条消息，但本版本的同步插件不支持]",
          )

        if creator.failure?
          Rails.logger.warn "[Telegram Bridge] Chat message failed to send:\n#{creator.inspect_steps.inspect}\n#{creator.inspect_steps.error}"
        end

        update_user_profile_from_tg(fake_user.user, message, channel_id)
      end

      ::ChatBridgeModule::Provider::TelegramBridge::TelegramEvent.on(:message) do |message|
        Scheduler::Defer.later("Bridge a telegram message to discourse") do
          ::ChatBridgeModule::Provider::TelegramBridge.handleTgMessage message
        end
      end
    end
  end
end

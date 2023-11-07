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

      def self.handleTgMessage(message, edit = false)
        return unless SiteSetting.chat_bridge_enabled
        return unless SiteSetting.chat_enabled

        channel_id =
          ::ChatBridgeModule::Provider::TelegramBridge.getChannelId? message["chat"]["id"]

        bot = ::ChatBridgeModule::Provider::TelegramBridge::TelegramBot.new(channel_id)

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

        creator = nil
        if edit
          message_id =
            ChatBridgeModule::Provider::TelegramBridge::ChatBridgeTelegramMessage.find_by(
              tg_msg_id: message["message_id"],
              tg_chat_id: message["chat"]["id"],
            ).message_id
          creator =
            ::ChatBridgeModule::UpdateMessage.call(
              message_id:,
              guardian: ::ChatBridgeModule::GhostUserGuardian.new(fake_user.user),
              **::ChatBridgeModule::Provider::TelegramBridge.make_discourse_message(
                bot,
                fake_user.user,
                message,
              ),
            )
        else
          creator =
            ::ChatBridgeModule::CreateMessage.call(
              chat_channel_id: channel_id,
              guardian: ::ChatBridgeModule::GhostUserGuardian.new(fake_user.user),
              **::ChatBridgeModule::Provider::TelegramBridge.make_discourse_message(
                bot,
                fake_user.user,
                message,
              ),
            )
        end

        if creator.failure?
          Rails.logger.warn "[Telegram Bridge] Chat message failed to send:\n#{creator.inspect_steps.inspect}\n#{creator.inspect_steps.error}"
          return nil
        end

        ::ChatBridgeModule::Provider::TelegramBridge::ChatBridgeTelegramMessage.create_or_update!(
          tg_msg_id: message["message_id"],
          tg_chat_id: message["chat"]["id"],
          message_id: creator.message.id,
          raw: JSON.dump(message),
          user_id: fake_user.user.id,
          tg_user_id: message["from"].present? && message["from"]["id"],
          chat_id: channel_id,
        )

        update_user_profile_from_tg(fake_user.user, message, channel_id)
      end

      ::ChatBridgeModule::Provider::TelegramBridge::TelegramEvent.on(:message) do |message|
        Scheduler::Defer.later("Bridge a telegram message to discourse") do
          ::ChatBridgeModule::Provider::TelegramBridge.handleTgMessage message
        end
      end

      ::ChatBridgeModule::Provider::TelegramBridge::TelegramEvent.on(:edited_message) do |message|
        Scheduler::Defer.later("Bridge a telegram message to discourse") do
          ::ChatBridgeModule::Provider::TelegramBridge.handleTgMessage message, true
        end
      end

      def self.handleDiscourseMessage(message, channel, user, usage = 0)
        # usage:
        # 0 - create
        # 1 - edit
        # 2 - trash

        return unless SiteSetting.chat_bridge_enabled
        return unless SiteSetting.chat_enabled

        bot = ::ChatBridgeModule::Provider::TelegramBridge::TelegramBot.new(channel.id)
        return nil unless bot.valid?
        fake_user = ::ChatBridgeModule::FakeUser::ChatBridgeFakeUser.find_by(user_id: user.id)
        if fake_user&.provider_id == ::ChatBridgeModule::Provider::TelegramBridge::PROVIDER_ID
          return nil
        end

        response_message = nil

        response_message = make_telegram_message(bot, message, channel, user, usage)

        puts "---------------"
        puts "respond"
        puts response_message
        puts "---------------"

        if response_message.present? && response_message["ok"]
          ::ChatBridgeModule::Provider::TelegramBridge::ChatBridgeTelegramMessage.create_or_update!(
            tg_msg_id: response_message["result"]["message_id"],
            tg_chat_id: response_message["result"]["chat"]["id"],
            message_id: message.id,
            raw: JSON.dump(response_message["result"]),
            user_id: user.id,
            tg_user_id: response_message["result"]["from"]["id"],
            chat_id: channel.id,
          )
        end
      end

      DiscourseEvent.on(:chat_message_created) do |*args|
        Scheduler::Defer.later("Bridge a discourse message to telegram") do
          ::ChatBridgeModule::Provider::TelegramBridge.handleDiscourseMessage *args
        end
      end
      DiscourseEvent.on(:chat_message_edited) do |*args|
        Scheduler::Defer.later("Bridge a discourse message to telegram") do
          ::ChatBridgeModule::Provider::TelegramBridge.handleDiscourseMessage(*args, 1)
        end
      end
      DiscourseEvent.on(:chat_message_trashed) do |*args|
        Scheduler::Defer.later("Bridge a discourse message to telegram") do
          ::ChatBridgeModule::Provider::TelegramBridge.handleDiscourseMessage(*args, 2)
        end
      end
    end
  end
end

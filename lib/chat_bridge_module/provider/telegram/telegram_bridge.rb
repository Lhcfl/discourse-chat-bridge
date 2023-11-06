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

      class HandleTgMessage
        include Service::Base

        # @!method call(message:, edit:)
        #   @param message [Telegram Message] Telegram message
        #   @param edit [Boolean] [Optional] If this is a message edition

        policy :require_plugin_enabled
        contract
        model :channel_id
        policy :require_channel_id_vaild
        policy :require_message_from_valid
        model :bot
        model :fake_user

        model :message_to_edit, optional: true
        model :message_creation
        policy :message_creation_succeed
        step :record_message
        step :after_succeed

        class Contract
          attribute :message
          attribute :edit, :boolean, default: false

          validates :message, presence: true
        end

        private

        def require_plugin_enabled(*)
          SiteSetting.chat_bridge_enabled && SiteSetting.chat_enabled
        end

        def fetch_channel_id(message:, **)
          ::ChatBridgeModule::Provider::TelegramBridge.getChannelId? message["chat"]["id"]
        end

        def require_channel_id_vaild(channel_id:, **)
          channel_id.present?
        end

        def require_message_from_valid(message:, **)
          message["from"].present? && message["from"]["id"].present?
        end

        def fetch_bot(channel_id:, **)
          ::ChatBridgeModule::Provider::TelegramBridge::TelegramBot.new(channel_id)
        end

        def fetch_fake_user(message:, **)
          ::ChatBridgeModule::FakeUser::ChatBridgeFakeUser.get_or_create(
            ::ChatBridgeModule::Provider::TelegramBridge::PROVIDER_ID,
            message["from"]["id"].to_i,
            ::ChatBridgeModule::Provider::TelegramBridge::PROVIDER_SLUG,
            "#{message["from"]["id"]}.tgid",
          )
        end

        def fetch_message_to_edit(message:, contract:, **)
          if contract.edit
            ChatBridgeModule::Provider::TelegramBridge::ChatBridgeTelegramMessage.find_by(
              tg_msg_id: message["message_id"],
              tg_chat_id: message["chat"]["id"],
            )
          end
        end

        def fetch_message_creation(message:, bot:, fake_user:, channel_id:, message_to_edit:, **)
          if message_to_edit.present?
            ::ChatBridgeModule::UpdateMessage.call(
              message_id: message_to_edit.message_id,
              guardian: ::ChatBridgeModule::GhostUserGuardian.new(fake_user.user),
              **::ChatBridgeModule::Provider::TelegramBridge.make_discourse_message(
                bot,
                fake_user.user,
                message,
              ),
            )
          else
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
        end

        def message_creation_succeed(message_creation:, **)
          if message_creation.failure?
            raise "In message creation: #{creator.inspect_steps.inspect}\n#{creator.inspect_steps.error}"
          end
          true
        end

        def record_message(message:, message_creation:, fake_user:, channel_id:, **)
          ::ChatBridgeModule::Provider::TelegramBridge::ChatBridgeTelegramMessage.create_or_update!(
            tg_msg_id: message["message_id"],
            tg_chat_id: message["chat"]["id"],
            message_id: message_creation.message_instance.id,
            raw: JSON.dump(message),
            user_id: fake_user.user.id,
            tg_user_id: message["from"].present? && message["from"]["id"],
            chat_id: channel_id,
          )
        end

        def after_succeed(fake_user:, message:, channel_id:, **)
          ::ChatBridgeModule::Provider::TelegramBridge.update_user_profile_from_tg(
            fake_user.user,
            message,
            channel_id,
          )
        end
      end

      ::ChatBridgeModule::Provider::TelegramBridge::TelegramEvent.on(:message) do |message|
        Scheduler::Defer.later("Bridge a telegram message to discourse") do
          ::ChatBridgeModule::Provider::TelegramBridge::HandleTgMessage
            .call(message:)
            .tap do |result|
              if result.failure?
                Rails.logger.warn(
                  "[Telegram Bridge] Failed to bridge message: \n#{result.inspect_steps.inspect}\n#{result.inspect_steps.error} \n----------\nIn message: #{YAML.dump(message)}",
                )
              end
            end
        end
      end

      ::ChatBridgeModule::Provider::TelegramBridge::TelegramEvent.on(:edited_message) do |message|
        Scheduler::Defer.later("Bridge a telegram message edit to discourse") do
          ::ChatBridgeModule::Provider::TelegramBridge::HandleTgMessage
            .call(message:, edit: true)
            .tap do |result|
              if result.failure?
                Rails.logger.warn(
                  "[Telegram Bridge] Failed to bridge edited_message: \n#{result.inspect_steps.inspect}\n#{result.inspect_steps.error} \n----------\nIn message: #{YAML.dump(message)}\n----------\nMessage to edit: #{YAML.dump(result.message_to_edit)}\n",
                )
              end
            end
        end
      end

      class HandleDiscourseMessage
        include Service::Base

        policy :require_plugin_enabled
        contract
        model :bot
        policy :require_bot_valid
        step :ensure_not_bridge_back
        model :telegram_message
        step :debug_log_respond
        step :record_message

        class Contract
          attribute :message
          attribute :channel
          attribute :user
          attribute :event, default: :chat_message_created

          validates :message, presence: true
          validates :channel, presence: true
          validates :user, presence: true
        end

        private

        def require_plugin_enabled(*)
          SiteSetting.chat_bridge_enabled && SiteSetting.chat_enabled
        end

        def fetch_bot(contract:, **)
          ::ChatBridgeModule::Provider::TelegramBridge::TelegramBot.new(contract.channel.id)
        end

        def require_bot_valid(bot:, **)
          bot.valid?
        end

        def ensure_not_bridge_back(contract:, **)
          if ::ChatBridgeModule::FakeUser::ChatBridgeFakeUser.find_by(
               user_id: contract.user.id,
             )&.provider_id == ::ChatBridgeModule::Provider::TelegramBridge::PROVIDER_ID
            fail!("BRIDGE_BACK")
          end
        end

        def fetch_telegram_message(bot:, contract:, **)
          ::ChatBridgeModule::Provider::TelegramBridge.make_telegram_message(
            bot:,
            message: contract.message,
            channel: contract.channel,
            user: contract.user,
            event: contract.event,
          )
        end

        def debug_log_respond(telegram_message:, **)
          Rails.logger.debug (
                               "[Telegram Bridge] Respond from telegram:\n" +
                                 YAML.dump(telegram_message)
                             )
        end

        def record_message(telegram_message:, contract:, **)
          if !telegram_message["ok"]
            fail! ("Telegram responsed with not ok. Details: \n#{YAML.dump(telegram_message)}")
          end

          ::ChatBridgeModule::Provider::TelegramBridge::ChatBridgeTelegramMessage.create_or_update!(
            tg_msg_id: telegram_message["result"]["message_id"],
            tg_chat_id: telegram_message["result"]["chat"]["id"],
            message_id: contract.message.id,
            raw: JSON.dump(telegram_message["result"]),
            user_id: contract.user.id,
            tg_user_id: telegram_message["result"]["from"]["id"],
            chat_id: contract.channel.id,
          )
        end
      end

      DiscourseEvent.on(:chat_message_created) do |message, channel, user|
        Scheduler::Defer.later("Bridge a discourse message to telegram") do
          ::ChatBridgeModule::Provider::TelegramBridge::HandleDiscourseMessage
            .call(message:, channel:, user:, event: :chat_message_created)
            .tap do |result|
              if result.failure?
                unless result.inspect_steps.error == "BRIDGE_BACK"
                  Rails.logger.warn(
                    "[Telegram Bridge] Failed to bridge message to telegram: \n#{result.inspect_steps.inspect}\n#{result.inspect_steps.error} \n----------\nIn message: #{YAML.dump(message)}",
                  )
                end
              end
            end
        end
      end
      DiscourseEvent.on(:chat_message_edited) do |message, channel, user|
        Scheduler::Defer.later("Bridge a discourse message to telegram") do
          ::ChatBridgeModule::Provider::TelegramBridge::HandleDiscourseMessage
            .call(message:, channel:, user:, event: :chat_message_edited)
            .tap do |result|
              if result.failure?
                unless result.inspect_steps.error == "BRIDGE_BACK"
                  Rails.logger.warn(
                    "[Telegram Bridge] Failed to bridge message to telegram: \n#{result.inspect_steps.inspect}\n#{result.inspect_steps.error} \n----------\nIn message: #{YAML.dump(message)}",
                  )
                end
              end
            end
        end
      end
      DiscourseEvent.on(:chat_message_trashed) do |message, channel, user|
        Scheduler::Defer.later("Bridge a discourse message to telegram") do
          ::ChatBridgeModule::Provider::TelegramBridge::HandleDiscourseMessage
            .call(message:, channel:, user:, event: :chat_message_trashed)
            .tap do |result|
              if result.failure?
                unless result.inspect_steps.error == "BRIDGE_BACK"
                  Rails.logger.warn(
                    "[Telegram Bridge] Failed to bridge message to telegram: \n#{result.inspect_steps.inspect}\n#{result.inspect_steps.error} \n----------\nIn message: #{YAML.dump(message)}",
                  )
                end
              end
            end
        end
      end
    end
  end
end

# frozen_string_literal: true

module ::ChatBridgeModule::Provider::TelegramBridge
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
    model :telegram_message
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
        raise "In message creation: #{message_creation.inspect_steps.inspect}\n#{message_creation.inspect_steps.error}"
      end
      true
    end

    def fetch_telegram_message(message:, message_creation:, fake_user:, channel_id:, **)
      ::ChatBridgeModule::Provider::TelegramBridge::ChatBridgeTelegramMessage.create_or_update!(
        tg_msg_id: message["message_id"],
        tg_chat_id: message["chat"]["id"],
        message_id:
          if message_creation.respose_to? :message_instance
            message_creation.message_instance.id
          else
            message_creation.message.id
          end,
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
end

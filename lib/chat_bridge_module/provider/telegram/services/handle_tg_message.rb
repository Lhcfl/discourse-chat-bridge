# frozen_string_literal: true

module ::ChatBridgeModule::Provider::Telegram::Services
  class HandleTgMessage
    include Service::Base

    # @!method call(params:)
    #   @param message [Telegram Message] Telegram message
    #   @param edit [Boolean] [Optional] If this is a params.message edition

    params do
      attribute :message
      attribute :edit, :boolean, default: false

      validates :message, presence: true
    end

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

    private

    def fetch_channel_id(params:)
      chat_id = params.message["chat"]["id"]
      return nil if chat_id.nil?

      SiteSetting
        .chat_telegram_bridges
        .split("|")
        .each do |config|
          channel_id, cid, _token = config.split(",")
          return channel_id if cid.to_s == chat_id.to_s
        end

      nil
    end

    def require_channel_id_vaild(channel_id:)
      channel_id.present?
    end

    def require_message_from_valid(params:)
      params.message["from"].present? && params.message["from"]["id"].present?
    end

    def fetch_bot(channel_id:)
      ::ChatBridgeModule::Provider::Telegram::TelegramApi::TelegramBot.new(channel_id)
    end

    def fetch_fake_user(params:)
      ::ChatBridgeModule::ChatBridgeFakeUser.get_or_create(
        ::ChatBridgeModule::Provider::Telegram::PROVIDER_ID,
        params.message["from"]["id"].to_i,
        ::ChatBridgeModule::Provider::Telegram::PROVIDER_SLUG,
        "#{params.message["from"]["id"]}.tgid",
      )
    end

    def fetch_message_to_edit(params:)
      if params.edit
        ::ChatBridgeModule::Provider::Telegram::ChatBridgeTelegramMessage.find_by(
          tg_msg_id: params.message["message_id"],
          tg_chat_id: params.message["chat"]["id"],
        )
      end
    end

    def fetch_message_creation(params:, bot:, fake_user:, channel_id:, message_to_edit:)
      if message_to_edit.present?
        ::Chat::UpdateMessage.call(
          guardian: ::ChatBridgeModule::GhostUserGuardian.new(fake_user.user),
          params: {
            message_id: message_to_edit.message_id,
            **::ChatBridgeModule::Provider::Telegram::Parsers::DiscourseMessage.make(
              bot,
              fake_user.user,
              params.message,
            ),
          },
        )
      else
        ::Chat::CreateMessage.call(
          guardian: ::ChatBridgeModule::GhostUserGuardian.new(fake_user.user),
          params: {
            chat_channel_id: channel_id,
            **::ChatBridgeModule::Provider::Telegram::Parsers::DiscourseMessage.make(
              bot,
              fake_user.user,
              params.message,
            ),
          },
          options: {
            enforce_membership: false,
          },
        )
      end
    end

    def message_creation_succeed(message_creation:)
      if message_creation.failure?
        raise "In params.message creation: #{message_creation.inspect_steps}"
      end
      true
    end

    def fetch_telegram_message(params:, message_creation:, fake_user:, channel_id:)
      ::ChatBridgeModule::Provider::Telegram::ChatBridgeTelegramMessage.create_or_update!(
        tg_msg_id: params.message["message_id"],
        tg_chat_id: params.message["chat"]["id"],
        message_id: message_creation.message_instance.id,
        raw: JSON.dump(params.message),
        user_id: fake_user.user.id,
        tg_user_id: params.message["from"].present? && params.message["from"]["id"],
        chat_id: channel_id,
      )
    end

    def after_succeed(fake_user:, params:, channel_id:)
      Scheduler::Defer.later("Telegram Bridge Update User Profile") do
        ::ChatBridgeModule::Provider::Telegram::Services::UpdateUserProfile.call(params: {
          user: fake_user.user,
          message: params.message,
          channel_id: channel_id,
        })
      end
    end
  end
end

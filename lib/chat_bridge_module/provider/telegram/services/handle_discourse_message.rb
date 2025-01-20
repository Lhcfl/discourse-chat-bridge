# frozen_string_literal: true

module ::ChatBridgeModule::Provider::Telegram::Services
  class HandleDiscourseMessage
    include Service::Base

    params do
      attribute :message
      attribute :channel
      attribute :user
      attribute :event, default: :chat_message_created

      validates :message, presence: true
      validates :channel, presence: true
      validates :user, presence: true
    end

    model :bot
    step :ensure_bot_valid
    step :ensure_not_bridge_back
    model :telegram_response
    step :debug_log_respond
    step :fail_when_tg_message_not_ok
    model :telegram_message

    private

    def fetch_bot(params:)
      ::ChatBridgeModule::Provider::Telegram::TelegramApi::TelegramBot.new(params.channel.id)
    end

    def ensure_bot_valid(bot:)
      fail!("INVALID_BOT") unless bot.valid?
    end

    def ensure_not_bridge_back(params:)
      if ::ChatBridgeModule::ChatBridgeFakeUser.find_by(user_id: params.user.id)&.provider_id ==
           ::ChatBridgeModule::Provider::Telegram::PROVIDER_ID
        fail!("BRIDGE_BACK")
      end
    end

    def fetch_telegram_response(bot:, params:)
      ::ChatBridgeModule::Provider::Telegram::TelegramMessage.make(
        bot:,
        message: params.message,
        channel: params.channel,
        user: params.user,
        event: params.event,
      )
    end

    def debug_log_respond(telegram_response:)
      Rails.logger.debug(
        "[Telegram Bridge] Respond from telegram:\n" + YAML.dump(telegram_response),
      )
    end

    def fail_when_tg_message_not_ok(telegram_response:)
      if !telegram_response["ok"]
        fail!("Telegram responsed with not ok. Details: \n#{YAML.dump(telegram_response)}")
      end
    end

    def fetch_telegram_message(telegram_response:, params:)
      if telegram_response["result"].class == Hash && telegram_response["result"]["message_id"]
        ::ChatBridgeModule::Provider::Telegram::ChatBridgeTelegramMessage.create_or_update!(
          tg_msg_id: telegram_response["result"]["message_id"],
          tg_chat_id: telegram_response["result"]["chat"]["id"],
          message_id: params.message.id,
          raw: JSON.dump(telegram_response["result"]),
          user_id: params.user.id,
          tg_user_id: telegram_response["result"]["from"]["id"],
          chat_id: params.channel.id,
        )
      else
        telegram_response["result"]
      end
    end
  end
end

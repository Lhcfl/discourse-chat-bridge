# frozen_string_literal: true

module ::ChatBridgeModule::Provider::Telegram::TelegramApi
  class Sender
    include Service::Base

    private

    def self.prepare_params
      # prepare params

      params do
        attribute :bot
        attribute :message
        attribute :channel
        attribute :user

        validates :bot, presence: true
        validates :message, presence: true
        validates :channel, presence: true
        validates :user, presence: true
      end
    end

    def fetch_tg_message(params:)
      ::ChatBridgeModule::Provider::Telegram::ChatBridgeTelegramMessage.find_by(
        message_id: params.message.id,
      )
    end

    def fetch_text(params:)
      "<b>#{params.user.username}</b>: #{::ChatBridgeModule::Provider::Telegram::Parsers::TgHtml.parse(params.message.cooked)}"
    end

    def fetch_response(params:, to_send:)
      params.bot._request(@methodName, to_send)
    end
  end
end

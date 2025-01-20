# frozen_string_literal: true

module ::ChatBridgeModule::Provider::Telegram::TelegramApi
  class CreateMessage < Sender
    prepare_params
    model :to_send
    model :text
    step :link_reply_to
    step :determin_type
    model :response

    private

    def fetch_to_send(params:)
      { chat_id: params.bot.group_id, parse_mode: "HTML" }
    end

    def link_reply_to(params:, to_send:)
      if params.message.in_reply_to_id.present?
        reply_to =
          ::ChatBridgeModule::Provider::Telegram::ChatBridgeTelegramMessage.find_by(
            message_id: params.message.in_reply_to_id,
          )
        if reply_to.present?
          to_send[:reply_to_message_id] = reply_to.tg_msg_id
          to_send[:allow_sending_without_reply] = true
        end
      end
    end

    def determin_type(params:, to_send:, text:)
      if params.message.uploads.blank?
        @methodName = "sendMessage"
        to_send[:text] = text
      else
        @methodName = "sendPhoto"
        to_send[:caption] = text
        to_send[:photo] = "#{Discourse.base_url}#{params.message.uploads[0].url}"
      end
    end
  end
end

# frozen_string_literal: true

module ::ChatBridgeModule::Provider::Telegram::TelegramApi
  class EditMessage < Sender
    prepare_params
    model :tg_message
    model :to_send
    model :text
    step :determin_type
    model :response

    private

    def fetch_to_send(params:, tg_message:)
      { chat_id: params.bot.group_id, parse_mode: "HTML", message_id: tg_message.tg_msg_id }
    end

    def determin_type(tg_message:, text:, to_send:)
      if JSON.parse(tg_message.raw)["caption"].present?
        @methodName = "editMessageCaption"
        to_send[:caption] = text
      else
        @methodName = "editMessageText"
        to_send[:text] = text
      end
    end
  end
end

# frozen_string_literal: true

module ::ChatBridgeModule::Provider::Telegram::TelegramApi
  class DeleteMessage < Sender
    prepare_params
    model :tg_message
    model :to_send
    model :response

    private

    def fetch_to_send(params:, tg_message:)
      @methodName = "deleteMessage"
      { chat_id: params.bot.group_id, message_id: tg_message.tg_msg_id }
    end
  end
end

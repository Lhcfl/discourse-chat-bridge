# frozen_string_literal: true

module ChatBridgeModule::Provider::Telegram
  module TelegramMessage
    def self.make(bot:, message:, channel:, user:, event:)
      args = { params: { bot:, message:, channel:, user: } }

      begin
        creator =
          case event
          when :chat_message_created
           TelegramApi::CreateMessage.call(**args)
          when :chat_message_edited
           TelegramApi::EditMessage.call(**args)
          when :chat_message_trashed
           TelegramApi::DeleteMessage.call(**args)
          else
            raise "Not implemented chat message event"
          end
      rescue => exception
        raise "Failed to make telegram messages: Exception: #{exception}"
      ensure
        if creator&.failure?
          raise "Failed to make telegram messages: Inspect: #{creator.inspect_steps}"
        end
      end

      creator.response
    end
  end
end


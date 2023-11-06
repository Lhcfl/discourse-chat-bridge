# frozen_string_literal: true

module ::ChatBridgeModule
  module Provider
    module TelegramBridge
      class TelegramMessageCreator
        include Service::Base

        contract
        model :to_send
        model :text
        step :link_reply_to
        step :determin_type
        model :response

        class Contract
          attribute :bot
          attribute :message
          attribute :channel
          attribute :user

          validates :bot, presence: true
          validates :message, presence: true
          validates :channel, presence: true
          validates :user, presence: true
        end

        private

        def fetch_to_send(bot:, **)
          { chat_id: bot.group_id, parse_mode: "HTML" }
        end

        def fetch_text(user:, message:, **)
          "<b>#{user.username}</b>: #{::ChatBridgeModule::Provider::TelegramBridge::TgHtml.parse(message.cooked)}"
        end

        def link_reply_to(message:, to_send:, **)
          if message.in_reply_to_id.present?
            reply_to =
              ::ChatBridgeModule::Provider::TelegramBridge::ChatBridgeTelegramMessage.find_by(
                message_id: message.in_reply_to_id,
              )
            if reply_to.present?
              to_send[:reply_to_message_id] = reply_to.tg_msg_id
              to_send[:allow_sending_without_reply] = true
            end
          end
        end

        def determin_type(message:, to_send:, text:, **)
          if message.uploads.blank?
            @methodName = "sendMessage"
            to_send[:text] = text
          else
            @methodName = "sendPhoto"
            to_send[:caption] = text
            to_send[:photo] = "#{Discourse.base_url}#{message.uploads[0].url}"
          end
        end

        def fetch_response(bot:, to_send:, **)
          bot._request(@methodName, to_send)
        end
      end

      class TelegramMessageEditor < TelegramMessageCreator
        contract
        model :tg_message
        model :to_send
        model :text
        step :determin_type
        model :response

        private

        def fetch_tg_message(message:, **)
          ::ChatBridgeModule::Provider::TelegramBridge::ChatBridgeTelegramMessage.find_by(
            message_id: message.id,
          )
        end

        def fetch_to_send(bot:, tg_message:, **)
          { chat_id: bot.group_id, parse_mode: "HTML", message_id: tg_message.tg_msg_id }
        end

        def determin_type(tg_message:, text:, to_send:, **)
          if JSON.parse(tg_message.raw)["caption"].present?
            @methodName = "editMessageCaption"
            to_send[:caption] = text
          else
            @methodName = "editMessageText"
            to_send[:text] = text
          end
        end
      end

      class TelegramMessageDeleter < TelegramMessageEditor
        contract
        model :tg_message
        model :to_send
        model :response

        private

        def fetch_to_send(bot:, tg_message:, **)
          @methodName = "deleteMessage"
          { chat_id: bot.group_id, message_id: tg_message.tg_msg_id }
        end
      end

      def self.make_telegram_message(bot:, message:, channel:, user:, event:)
        args = { bot:, message:, channel:, user: }
        creator =
          case event
          when :chat_message_created
            TelegramMessageCreator.call(**args)
          when :chat_message_edited
            TelegramMessageEditor.call(**args)
          when :chat_message_trashed
            TelegramMessageDeleter.call(**args)
          else
            raise "Not implemented chat message event"
          end

        if creator.failure?
          raise "Failed to make telegram messages: #{creator.inspect_steps.inspect}\n#{creator.inspect_steps.error}"
        end

        creator.response
      end
    end
  end
end

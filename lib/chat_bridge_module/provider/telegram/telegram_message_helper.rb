# frozen_string_literal: true

module ::ChatBridgeModule
  module Provider
    module TelegramBridge
      class TelegramMessageSender
        include Service::Base

        private

        def self.prepare_params
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
          ::ChatBridgeModule::Provider::TelegramBridge::ChatBridgeTelegramMessage.find_by(
            message_id: params.message.id,
          )
        end

        def fetch_text(params:)
          "<b>#{params.user.username}</b>: #{::ChatBridgeModule::Provider::TelegramBridge::TgHtml.parse(params.message.cooked)}"
        end

        def fetch_response(params:, to_send:)
          params.bot._request(@methodName, to_send)
        end
      end

      class TelegramMessageCreator < TelegramMessageSender
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
              ::ChatBridgeModule::Provider::TelegramBridge::ChatBridgeTelegramMessage.find_by(
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

      class TelegramMessageEditor < TelegramMessageSender
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

      class TelegramMessageDeleter < TelegramMessageSender
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

      def self.make_telegram_message(bot:, message:, channel:, user:, event:)
        args = { params: { bot:, message:, channel:, user: } }

        begin
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
end

# frozen_string_literal: true

module ::ChatBridgeModule
  module Provider
    module TelegramBridge
      def self.make_telegram_message(bot:, message:, channel:, user:, event:)
        # usage:
        # 0 - create
        # 1 - edit
        # 2 - trash

        to_send = { chat_id: bot.group_id, parse_mode: "HTML" }

        methodName = "sendMessage"

        if event == :chat_message_trashed
          the_message =
            ::ChatBridgeModule::Provider::TelegramBridge::ChatBridgeTelegramMessage.find_by(
              message_id: message.id,
            )
          return if the_message.blank?
          bot._request(
            "deleteMessage",
            { chat_id: bot.group_id, message_id: the_message.tg_msg_id },
          )
          return nil
        end

        if event == :chat_message_edited
          the_message =
            ::ChatBridgeModule::Provider::TelegramBridge::ChatBridgeTelegramMessage.find_by(
              message_id: message.id,
            )
          return if the_message.blank?
          to_send[:message_id] = the_message.tg_msg_id
          if JSON.parse(the_message.raw)["caption"].present?
            methodName = "editMessageCaption"
            to_send[
              :caption
            ] = "<b>#{user.username}</b>: #{::ChatBridgeModule::Provider::TelegramBridge::TgHtml.parse(message.cooked)}"
          else
            methodName = "editMessageText"
            to_send[
              :text
            ] = "<b>#{user.username}</b>: #{::ChatBridgeModule::Provider::TelegramBridge::TgHtml.parse(message.cooked)}"
          end
          return bot._request(methodName, to_send)
        end

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

        if message.uploads.blank?
          to_send[
            :text
          ] = "<b>#{user.username}</b>: #{::ChatBridgeModule::Provider::TelegramBridge::TgHtml.parse(message.cooked)}"
        else
          methodName = "sendPhoto"
          to_send[
            :caption
          ] = "<b>#{user.username}</b>: #{::ChatBridgeModule::Provider::TelegramBridge::TgHtml.parse(message.cooked)}"
          to_send[:photo] = "#{Discourse.base_url}#{message.uploads[0].url}"
        end

        response_message = bot._request(methodName, to_send)

        response_message
      end
    end
  end
end

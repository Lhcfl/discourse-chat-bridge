# frozen_string_literal: true

# module ::ChatBridgeModule::Provider::MatrixBridge
#   class HandleDiscourseMessage
#     include Service::Base

#     policy :require_plugin_enabled
#     contract
#     model :bot
#     step :ensure_bot_valid
#     step :ensure_not_bridge_back
#     model :telegram_response
#     step :debug_log_respond
#     step :fail_when_tg_message_not_ok
#     model :telegram_message

#     class Contract
#       attribute :message
#       attribute :channel
#       attribute :user
#       attribute :event, default: :chat_message_created

#       validates :message, presence: true
#       validates :channel, presence: true
#       validates :user, presence: true
#     end

#     private

#     def require_plugin_enabled(*)
#       SiteSetting.chat_bridge_enabled && SiteSetting.chat_enabled
#     end

#     def fetch_bot(contract:, **)
#       ::ChatBridgeModule::Provider::TelegramBridge::TelegramBot.new(contract.channel.id)
#     end

#     def ensure_bot_valid(bot:, **)
#       fail!("INVALID_BOT") if bot.valid?
#     end

#     def ensure_not_bridge_back(contract:, **)
#       if ::ChatBridgeModule::FakeUser::ChatBridgeFakeUser.find_by(
#            user_id: contract.user.id,
#          )&.provider_id == ::ChatBridgeModule::Provider::TelegramBridge::PROVIDER_ID
#         fail!("BRIDGE_BACK")
#       end
#     end

#     def fetch_telegram_response(bot:, contract:, **)
#       ::ChatBridgeModule::Provider::TelegramBridge.make_telegram_message(
#         bot:,
#         message: contract.message,
#         channel: contract.channel,
#         user: contract.user,
#         event: contract.event,
#       )
#     end

#     def debug_log_respond(telegram_response:, **)
#       Rails.logger.debug (
#                            "[Telegram Bridge] Respond from telegram:\n" +
#                              YAML.dump(telegram_response)
#                          )
#     end

#     def fail_when_tg_message_not_ok(telegram_response:, **)
#       if !telegram_response["ok"]
#         fail! ("Telegram responsed with not ok. Details: \n#{YAML.dump(telegram_response)}")
#       end
#     end

#     def fetch_telegram_message(telegram_response:, contract:, **)
#       if telegram_response["result"].class == Hash && telegram_response["result"]["message_id"]
#         ::ChatBridgeModule::Provider::TelegramBridge::ChatBridgeTelegramMessage.create_or_update!(
#           tg_msg_id: telegram_response["result"]["message_id"],
#           tg_chat_id: telegram_response["result"]["chat"]["id"],
#           message_id: contract.message.id,
#           raw: JSON.dump(telegram_response["result"]),
#           user_id: contract.user.id,
#           tg_user_id: telegram_response["result"]["from"]["id"],
#           chat_id: contract.channel.id,
#         )
#       else
#         telegram_response["result"]
#       end
#     end
#   end
# end

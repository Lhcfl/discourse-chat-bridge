# frozen_string_literal: true

module ::ChatBridgeModule::Provider::Telegram::Services
  module SetupWebhook
    def self.call
      newSecret = SecureRandom.hex
      SiteSetting.chat_telegram_bridge_secret_path = newSecret

      message = { url: Discourse.base_url + "/chat-bridge/telegram/hook/" + newSecret }

      SiteSetting
        .chat_telegram_bridges
        .split("|")
        .map do |config|
          cid, gid, tok = config.split(",")
          raise "Not valid config" if (cid.nil? || gid.nil? || tok.nil?)
          cid
        end
        .uniq
        .each do |cid|
          bot = ::ChatBridgeModule::Provider::Telegram::TelegramBot.new(cid)
          response = bot._request("setWebhook", message)
          if response["ok"] != true
            # If setting up webhook failed, disable provider
            # SiteSetting.chat_bridge_enabled = false
            Rails.logger.error(
              "Failed to setup telegram webhook for chat channel #{cid}. Message data= " +
                message.to_json + " response=" + response.to_json,
            )
          end
        end
    end
  end
end

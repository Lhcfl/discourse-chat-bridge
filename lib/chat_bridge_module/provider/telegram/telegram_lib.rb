# frozen_string_literal: true

module ::ChatBridgeModule
  module Provider
    module TelegramBridge

      class TelegramBot
        def initialize(discourse_chat_channel_id)
          @vaild = false
          raise "No channel id" if discourse_chat_channel_id.nil?

          SiteSetting.chat_telegram_bridges.split("|").each do |config|
            cid, gid, tok = config.split(",")
            if cid == discourse_chat_channel_id
              @group_id = gid
              @token = tok
              @vaild = true
            end
          end
        end

        def vaild?
          @vaild
        end

        def bot_token
          @token
        end

        def group_id
          @token
        end

        def self._request(methodName, message)
          raise "Telegram bot is not valid" unless valid?

          http = FinalDestination::HTTP.new("api.telegram.org", 443)
          http.use_ssl = true
  
          uri = URI("https://api.telegram.org/bot#{bot_token}/#{methodName}")
  
          req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
          req.body = message.to_json
          response = http.request(req)
  
          responseData = JSON.parse(response.body)
  
          responseData
        end
      end
      
      def self.setup_webhook
        newSecret = SecureRandom.hex
        SiteSetting.chat_telegram_bridge_secret_path = newSecret

        message = { url: Discourse.base_url + "/chat-bridge/telegram/hook/" + newSecret }

        SiteSetting.chat_telegram_bridges.map({ |config|
          cid, gid, tok = config.split(",")
          raise "Not vaild config" if (cid.nil? || gid.nil? || tok.nil?)
          cid
        }).uniq.each do |cid|
          bot = ::ChatBridgeModule::Provider::TelegramBridge::TelegramBot.new(cid)
          response = bot.do_api_request("setWebhook", message)
          if response["ok"] != true
            # If setting up webhook failed, disable provider
            SiteSetting.chat_bridge_enabled = false
            Rails.logger.error(
              "Failed to setup telegram webhook for chat channel #{cid}. Message data= " + message.to_json + " response=" +
                response.to_json,
            )
          end
        end

      end

      class TelegramEvent < DiscourseEvent
      end

      class TelegramWebhookController < ::ApplicationController
        requires_plugin ::ChatBridgeModule::PLUGIN_NAME

        before_action :telegram_token_valid?, only: :hook
        skip_before_action :check_xhr,
                           :preload_json,
                           :verify_authenticity_token,
                           :redirect_to_login_if_required,
                           only: :hook

        def hook
          [
            :message,
            :edited_message,
            :channel_post,
            :edited_channel_post,
            :inline_query,
            :chosen_inline_result,
            :callback_query,
            :shipping_query,
            :pre_checkout_query,
            :poll,
            :poll_answer,
            :my_chat_member,
            :chat_member,
            :chat_join_request,
          ].each do |symbol|
            if params.key?(symbol.to_s)
              ::ChatBridgeModule::Provider::TelegramBridge::TelegramEvent.trigger(symbol, params[symbol.to_s])
            end
          end

          # Always give telegram a success message, otherwise we'll stop receiving webhooks
          data = { success: true }
          render json: data
        end

        def telegram_token_valid?
          params.require(:token)
    
          if SiteSetting.chat_telegram_bridge_secret_path.blank? ||
               SiteSetting.chat_telegram_bridge_secret_path != params[:token]
            raise Discourse::InvalidAccess.new
          end
        end
      end

      class TelegramEngine < ::Rails::Engine
        engine_name ::ChatBridgeModule::PLUGIN_NAME + "-telegram"
        isolate_namespace ::ChatBridgeModule::Provider::TelegramBridge
      end
    
      TelegramEngine.routes.draw { post "hook/:token" => "telegram_webhook#hook" }

      Discourse::Application.routes.draw { mount ::ChatBridgeModule::Engine, at: "chat-bridge" }
    
    end
  end
end

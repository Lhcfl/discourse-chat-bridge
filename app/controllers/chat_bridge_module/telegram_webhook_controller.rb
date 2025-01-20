module ::ChatBridgeModule
  class TelegramWebhookController < ::ApplicationController
    requires_plugin ::ChatBridgeModule::PLUGIN_NAME

    before_action :telegram_token_valid?, only: :hook
    skip_before_action :check_xhr,
                      :preload_json,
                      :verify_authenticity_token,
                      :redirect_to_login_if_required,
                      only: :hook

    def hook
      %i[
        message
        edited_message
        channel_post
        edited_channel_post
        inline_query
        chosen_inline_result
        callback_query
        shipping_query
        pre_checkout_query
        poll
        poll_answer
        my_chat_member
        chat_member
        chat_join_request
      ].each do |symbol|
        if params.key?(symbol.to_s)
          ::ChatBridgeModule::Provider::Telegram::TelegramEvent.trigger(
            symbol,
            params[symbol.to_s],
          )
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
end

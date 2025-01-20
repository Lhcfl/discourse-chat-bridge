# frozen_string_literal: true

module ChatBridgeModule::Provider::Telegram::EventsExtension
  DiscourseEvent.on(:site_setting_changed) do |setting_name, old_value, new_value| # rubocop:disable Discourse/Plugins/UsePluginInstanceOn
    isEnabledSetting = setting_name == :chat_bridge_enabled
    isSettingTelegramBridge = setting_name == :chat_telegram_bridges

    if (isEnabledSetting || isSettingTelegramBridge)
      enabled = isEnabledSetting ? new_value == true : SiteSetting.chat_bridge_enabled

      if enabled && SiteSetting.chat_telegram_bridges.present?
        Scheduler::Defer.later("Setup Telegram Bridge Webhook") do
          ChatBridgeModule::Provider::Telegram::Services::SetupWebhook.call
        end
      end
    end
  end
end

# frozen_string_literal: true

DiscourseEvent.on(:site_setting_changed) do |setting_name, old_value, new_value|
  isEnabledSetting = setting_name == :chat_bridge_enabled
  isSettingTelegramBridge = setting_name == :chat_telegram_bridges

  if (isEnabledSetting || isSettingTelegramBridge)
    enabled = isEnabledSetting ? new_value == true : SiteSetting.chat_bridge_enabled

    if enabled && SiteSetting.chat_telegram_bridges.present?
      Scheduler::Defer.later("Setup Telegram Bridge Webhook") do
        ChatBridgeModule::Provider::TelegramBridge.setup_webhook
      end
    end
  end
end

# frozen_string_literal: true

module ::ChatBridgeModule::Provider::Telegram::Services
  class UpdateUserProfile
    include Service::Base

    params do
      attribute :message
      attribute :channel_id
      attribute :user
      attribute :bot

      validates :message, presence: true
      validates :user, presence: true
      validates :bot, presence: true
      validates :channel_id, presence: true
    end

    step :set_name
    step :set_username
    step :update_avatar

    private

    def set_name(params:)
      name = params.message["from"]["first_name"]
      begin
        name = "#{name} #{params.message["from"]["last_name"]}" if params.message["from"][
          "last_name"
        ]
        name = "[Telegram] #{name}"
        if params.user.name != name
          params.user.name = name
          params.user.save!
        end
      rescue => exception
        Rails.logger.warn(
          "[Telegram Bridge] Failed to update tg name \"#{name}\" for params.user @#{params.user.username}: #{exception}",
        )
      end
    end

    def set_username(params:)
      name = params.message["from"]["first_name"]
      begin
        name = params.message["from"]["username"] if params.message["from"]["username"]
        name = "#{name}.tg"
        if params.user.username != name
          params.user.username = name
          params.user.save!
        end
      rescue => exception
        Rails.logger.warn(
          "[Telegram Bridge] Failed to update tg username \"#{name}\" for params.user @#{params.user.username}: #{exception}",
        )
      end
    end

    def update_avatar(params:)
      response =
        params.bot._request(
          "getUserProfilePhotos",
          { user_id: params.message["from"]["id"], limit: 1 },
        )

      if response["ok"] && response["result"].present? && response["result"]["photos"].present? &&
           response["result"]["photos"][0].present? &&
           response["result"]["photos"][0][0]["file_id"].present? &&
           response["result"]["photos"][0][0]["file_unique_id"].present?
        if ::ChatBridgeModule::Provider::Telegram::ChatBridgeTelegramUserInfo.find_by(
             tg_user_id: params.message["from"]["id"],
           )&.avatar_file_id == response["result"]["photos"][0][0]["file_unique_id"]
          return "Don't need update"
        end

        bot.get_upload_from_file(
          user: params.user,
          file: response["result"]["photos"][0][0],
          type: "avatar",
          filename: "avatar_tg_user#{params.user.id}",
        ) do |upload|
          params.user.update!(uploaded_avatar_id: upload.id)

          ::ChatBridgeModule::Provider::Telegram::ChatBridgeTelegramUserInfo.create_or_update!(
            user_id: params.user.id,
            tg_user_id: params.message["from"]["id"],
            avatar_file_id: response["result"]["photos"][0][0]["file_unique_id"],
          )
        end
      end
    end
  end
end

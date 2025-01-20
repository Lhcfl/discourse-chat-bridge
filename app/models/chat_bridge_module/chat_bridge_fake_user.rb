# frozen_string_literal: true

module ::ChatBridgeModule
  class ChatBridgeFakeUser < ActiveRecord::Base
    self.table_name = "chat_bridge_fake_users"

    belongs_to :user, class_name: :User, foreign_key: :user_id

    def self.get_or_create(provider_id, external_user_id, provider_slug, username)
      fake_user = nil
      if external_user_id.class == Integer
        fake_user = self.find_by(provider_id:, external_user_id:)
      else
        fake_user = self.find_by(provider_id:, external_username: external_user_id)
      end
      if fake_user.nil?
        u = User.find_by(username:)
        if u.nil?
          u =
            User.new.tap do |user|
              user.email = "#{provider_slug}_fakemail#{SecureRandom.hex}@fakedomain.neverexisted"
              user.username = username
              user.password = SecureRandom.hex
              user.username_lower = user.username.downcase
              user.active = true
              user.approved = true
              user.save!
              user.change_trust_level!(TrustLevel[1])
              user.activate
            end
        end
        if external_user_id.class == Integer
          fake_user = self.create(user_id: u.id, provider_id:, external_user_id:)
        else
          fake_user =
            self.create(user_id: u.id, provider_id:, external_username: external_user_id)
        end
      end

      fake_user
    end
  end
end

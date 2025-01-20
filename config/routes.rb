# frozen_string_literal: true

ChatBridgeModule::Engine.routes.draw do
  post "telegram/hook/:token" => "telegram_webhook#hook"
end

Discourse::Application.routes.draw { mount ::ChatBridgeModule::Engine, at: "chat-bridge" }

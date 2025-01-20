# frozen_string_literal: true

ChatBridgeModule::Engine.routes.draw { post "telegram/hook/:token" => "telegram_webhook#hook" }

Discourse::Application.routes.draw { mount ::ChatBridgeModule::Engine, at: "chat-bridge" }

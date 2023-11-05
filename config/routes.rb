# frozen_string_literal: true

ChatBridgeModule::Engine.routes.draw do
  get "/examples" => "examples#index"
  # define routes here
end

Discourse::Application.routes.draw { mount ::ChatBridgeModule::Engine, at: "chat-bridge" }

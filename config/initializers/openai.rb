require "localllm/openai/client"

Localllm::OpenAI::Client.configure do |config|
  config.api_key = Settings.openai.api_key
  config.base_url = Settings.openai.base_url
end

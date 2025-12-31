require "localllm/brave_search/mcp_client"

Localllm::BraveSearch::McpClient.configure do |config|
  config.base_url = Settings.brave_search.base_url
end

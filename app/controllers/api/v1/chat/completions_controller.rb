class Api::V1::Chat::CompletionsController < ::ApiController
  include ActionController::Live
  before_action :set_sse_headers

  def create
    chat_parameter = params.permit!.to_h.merge(
      tools: Localllm::BraveSearch::McpClient.new.to_openai_functions,
      tool_choice: "auto"
    )

    stream = Localllm::OpenAI::Client.chat.completions.stream_raw(chat_parameter)
    sse = SSE.new(response.stream, retry: 300)

    begin
      full_tool_calls = []
      stream.each do |chunk|
        sse.write(chunk)

        if tool_calls = chunk&.choices&.first&.delta&.tool_calls
          tool_calls.each do |tool_call|
            idx = tool_call.index
            full_tool_calls[idx] ||= { id: nil, function: { name: nil, arguments: "" } }
            # 2. 届いた ID や名前を更新（最初のチャンク以外は nil で届くことがあるため）
            full_tool_calls[idx][:id] ||= tool_call.id if tool_call.id
            full_tool_calls[idx][:function][:name] ||= tool_call.function.name if tool_call.function&.name
            # 3. 引数の断片をひたすら連結
            full_tool_calls[idx][:function][:arguments] << tool_call.function.arguments if tool_call.function&.arguments
          end
        end
      end

      if full_tool_calls.present?
        full_tool_calls.each do |tool_call|
          tool_call[:function][:arguments] = JSON.parse(tool_call[:function][:arguments])
        end
        # 2. ストリームを完走させて組み立てた tool_calls を履歴に追加
        # (注: Assistantとしての発話として追加する必要がある)
        assistant_tool_call_message = {
          role: "assistant",
          tool_calls: full_tool_calls.map do |tc|
            {
              id: tc[:id],
              type: "function",
              function: {
                name: tc[:function][:name],
                arguments: tc[:function][:arguments].to_json
              }
            }
          end
        }

        chat_parameter[:messages] << assistant_tool_call_message

        full_tool_calls.each do |tool_call|
          if tool_call[:function][:name].start_with?("brave_")
            mcp_result = Localllm::BraveSearch::McpClient.new.exec(**tool_call[:function]).body
            mcp_result = mcp_result["result"]["content"]
            content = mcp_result.map do |item|
              JSON.parse(item["text"])
            end
            chat_parameter[:messages] << {
              role: "tool",
              tool_call_id: tool_call[:id],
              content: content.to_json
            }
          end
        end
        # 4. 「第2ラウンド」：検索結果を反映させた最終回答を得る
        final_stream = Localllm::OpenAI::Client.chat.completions.stream_raw(chat_parameter)

        # 5. 再び SSE でフロントに流す
        final_stream.each do |chunk|
          sse.write(chunk)
        end
      end
      # ストリームの終了を知らせる（OpenAI 仕様）
      sse.write("[DONE]")
    ensure
      sse.close
    end
  end

  private

  def set_sse_headers
    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Cache-Control'] = 'no-cache'
    response.headers['X-Accel-Buffering'] = 'no' # nginx 対策
  end
end

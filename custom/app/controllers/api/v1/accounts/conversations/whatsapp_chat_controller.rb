# Arcaconsult: arquivar/desarquivar e silenciar/tirar o silêncio de uma conversa no
# WhatsApp do dono da caixa, para a Sofia (mcp-chatwoot) e qualquer cliente da API.
#
#   POST /api/v1/accounts/:account_id/conversations/:conversation_id/whatsapp_archive
#        { "archive": true | false }
#   POST /api/v1/accounts/:account_id/conversations/:conversation_id/whatsapp_mute
#        { "mute": true | false, "duration": "8h" | "1w" | "always" }   (duration só com mute=true; padrão "always")
#
# O comando é "dispara e esquece" no connector: 202 quer dizer que foi enfileirado, não que
# o celular já aplicou. Uma recusa do WhatsApp aparece só nos logs (command.failed).
class Api::V1::Accounts::Conversations::WhatsappChatController < Api::V1::Accounts::Conversations::BaseController
  rescue_from Custom::WhatsappChatState::Unsupported, Whatsapp::Session::Errors::NotSupported, with: :unsupported

  def archive
    archive = boolean_param!(:archive)
    return if performed?

    chat_state.archive!(archive)
    render json: { conversation_id: @conversation.display_id, archive: archive, status: 'queued' }, status: :accepted
  end

  def mute
    mute = boolean_param!(:mute)
    return if performed?

    duration = params[:duration].presence || 'always'
    unless !mute || Custom::WhatsappChatState::MUTE_DURATIONS.key?(duration)
      return render json: { error: "duration deve ser um de: #{Custom::WhatsappChatState::MUTE_DURATIONS.keys.join(', ')}" },
                    status: :unprocessable_entity
    end

    chat_state.mute!(mute, duration: duration)
    render json: { conversation_id: @conversation.display_id, mute: mute, duration: (duration if mute), status: 'queued' }.compact,
           status: :accepted
  end

  private

  def chat_state
    Custom::WhatsappChatState.new(@conversation)
  end

  # Só true/false de verdade (JSON booleano ou "true"/"false"), sem adivinhação.
  def boolean_param!(name)
    value = params[name]
    return value if [true, false].include?(value)
    return value == 'true' if %w[true false].include?(value)

    render json: { error: "#{name} deve ser true ou false" }, status: :unprocessable_entity
    nil
  end

  def unsupported(error)
    render json: { error: error.message }, status: :unprocessable_entity
  end
end

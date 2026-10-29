# Arcaconsult: rotas de arquivar/silenciar conversa no WhatsApp (controller em
# custom/app/controllers/api/v1/accounts/conversations/whatsapp_chat_controller.rb).
# Arquivo próprio, fora de config/routes.rb, para não conflitar a cada merge da fazer.ai.
Rails.application.routes.prepend do
  scope 'api/v1/accounts/:account_id/conversations/:conversation_id',
        module: 'api/v1/accounts/conversations', defaults: { format: 'json' } do
    post 'whatsapp_archive', to: 'whatsapp_chat#archive', as: :arca_whatsapp_archive
    post 'whatsapp_mute', to: 'whatsapp_chat#mute', as: :arca_whatsapp_mute
  end
end

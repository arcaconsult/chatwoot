# Arcaconsult: registra os listeners assíncronos da camada custom/.
module Custom::AsyncDispatcher
  def listeners
    super + [Custom::WhatsappAutoArchiveListener.instance]
  end
end

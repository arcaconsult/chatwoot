# Arcaconsult: arquiva/desarquiva e silencia/tira o silêncio de uma conversa no WhatsApp
# do próprio dono da caixa (provider `native`, connector com o patch `chat.archive` /
# `chat.mute`). Nada chega ao contato: é o mesmo app state sync que o celular usa.
#
# Usado pelos endpoints da Sofia (`Api::V1::Accounts::Conversations::WhatsappChatController`)
# e pela regra automática (`Custom::WhatsappAutoArchiveJob`).
class Custom::WhatsappChatState
  class Unsupported < StandardError; end

  # Opção por caixa, em `channel.provider_config`. Desligada por padrão: só a inbox que
  # tiver a chave `true` arquiva sozinha depois de uma mensagem enviada.
  AUTO_ARCHIVE_KEY = 'arca_auto_archive_outgoing'.freeze

  # Durações aceitas para silenciar. `always` é "para sempre" (sem fim).
  MUTE_DURATIONS = { '8h' => 8.hours, '1w' => 1.week, 'always' => nil }.freeze

  attr_reader :conversation

  def self.auto_archive?(inbox)
    channel = inbox&.channel
    channel.is_a?(Channel::Whatsapp) && channel.provider_config&.dig(AUTO_ARCHIVE_KEY) == true &&
      channel.session_capabilities.include?('archive')
  end

  def initialize(conversation)
    @conversation = conversation
  end

  def archive!(archive)
    facade.archive_conversation(conversation, archive: archive)
  end

  # `duration` é uma das chaves de MUTE_DURATIONS; ignorada quando `mute` é false.
  def mute!(mute, duration: 'always')
    raise ArgumentError, "duração inválida: #{duration.inspect}" if mute && !MUTE_DURATIONS.key?(duration)

    length = MUTE_DURATIONS[duration] if mute
    facade.mute_conversation(conversation, mute: mute, until_time: length&.from_now)
  end

  private

  def facade
    channel = conversation.inbox.channel
    # A capacidade em si é conferida na facade, que levanta NotSupported.
    raise Unsupported, 'esta caixa não é um WhatsApp por sessão' unless channel.is_a?(Channel::Whatsapp) && channel.session_provider?

    channel.provider_service
  end
end

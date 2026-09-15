# Arcaconsult: hides a conversation from everyone except members of the identically-named
# team (plus account administrators and any Chatwoot Agent Bot, e.g. the fazer.ai agent)
# once it carries a label whose name matches an existing team's name. Applies regardless of
# any other visibility a viewer would otherwise have -- including the Custom Role permission
# "conversation_manage" and plain inbox membership.
#
# The set of segregated labels is NOT a fixed list -- it is read live from `account.teams`
# on every call. Creating a Team "Ecommerce" and a Label "ecommerce" (Settings > Teams,
# Settings > Labels) is enough on its own to start segregating that label; no code change or
# deploy is needed for a new one. The trade-off that buys: any team name that happens to
# coincide with an existing or future label starts restricting it the moment both exist,
# with no separate review step -- accepted deliberately in favour of not needing a deploy
# per team. If that stops being the right trade-off, go back to a fixed SEGREGATED_LABELS
# list (git history has the version before this).
#
# Why this exists at all: Chatwoot's own visibility model (see Enterprise::ConversationPolicy)
# only narrows in one direction, from "see everything" down to "see mine" -- the moment an
# agent has any Custom Role, team_id stops mattering to it entirely (that code checks
# assignee_id and participant status, never team membership). There is no native permission
# level that means "see my team's conversations, minus everyone else's". Segregated
# departments share this fork's single WhatsApp inbox on purpose (a second number was ruled
# out), so this is the only way to keep them separated while every agent keeps full
# visibility of their own team's tickets, including each other's resolved history.
#
# An UNLABELED conversation is left alone -- this rule only ever narrows what a labeled
# conversation's visibility already was, it never restricts what has no label yet. That
# matters operationally: until something (a human or, later, the AI) applies a segregating
# label, a brand-new conversation stays visible the way it always was, so no team is locked
# out of its own inbox while waiting on classification. The "entrada" label every new
# conversation gets (via an Automation Rule, not this file) never becomes segregating on its
# own unless a team is deliberately also named "entrada".
#
# The `agent_bot?` exemption exists so the fazer.ai agent -- if it authenticates to
# Chatwoot as a proper Agent Bot rather than through a human agent's own token -- is never
# blocked by this rule while classifying a conversation into one of these labels. Without
# it, the AI would be locked out of the very conversations it just tagged.
#
# Scope: only ever narrows `show?` -- it can take visibility away, never grant it beyond what
# the normal chain already allows. `super` runs the full CE + Enterprise chain first; this
# only adds one more way to say no.
#
# Both Team#name and Label#title are downcased by their own model callbacks before saving
# (before_validation), so comparing them directly here (no explicit .downcase needed on
# either side) is correct by construction, not a coincidence to keep in sync by hand.
module Custom::ConversationPolicy
  def show?
    return false if hidden_by_segregated_label?

    super
  end

  private

  def hidden_by_segregated_label?
    account_team_names = account&.teams&.pluck(:name) || []
    matching_labels = record.cached_label_list_array & account_team_names
    return false if matching_labels.empty?
    return false if administrator? || agent_bot?

    user_team_names = user.teams.where(account_id: account&.id).pluck(:name)
    (matching_labels & user_team_names).empty?
  end
end

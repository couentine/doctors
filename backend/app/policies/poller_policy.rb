class PollerPolicy < ApplicationPolicy

  def initialize(current_user, poller_or_pollers)
    # NOTE: All pollers are public, there is no index

    true
  end

  #=== ACTION POLICIES ===#

  def show?
    true
  end

  #=== SCOPES ===#

  class Scope < ApplicationPolicy::Scope
    def resolve
      nil
    end
  end

end
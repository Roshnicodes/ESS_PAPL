class Ability
  include CanCan::Ability

  def initialize(user)
    return unless user&.active?

    if user.admin?
      can :manage, :all
      cannot :destroy, ActivityLog
      return
    end

    # --- every employee ---------------------------------------------------
    can :create, Tour
    can [ :update, :submit ], Tour, user_id: user.id, status: Tour::EDITABLE
    can :read,   Tour, user_id: user.id
    can :cancel, Tour, user_id: user.id
    can :read,   Tour, approver_id: user.id
    can :read,   Tour, l2_approver_id: user.id
    can :read,   Tour, l3_approver_id: user.id
    can :read,   Tour, approval_steps: { approver_id: user.id }
    # claim reviewers (incl. local mileage, which has no tour approver) may open the tour page via the 🕒 icon
    can :read,   Tour, tour_claim: { l1_approver_id: user.id }
    can :read,   Tour, tour_claim: { l2_approver_id: user.id }
    can :read,   Tour, tour_claim: { finance_approver_id: user.id }
    can :decide, Tour do |t| t.approvable_by?(user) end

    can :read,   TourClaim, user_id: user.id
    can :create, Tour
    can :create, TourClaim, tour: { user_id: user.id }
    can [ :update, :submit ], TourClaim, user_id: user.id, status: %w[draft returned]
    can :read,   TourClaim, l1_approver_id: user.id
    can :read,   TourClaim, l2_approver_id: user.id
    can :read,   TourClaim, approval_steps: { approver_id: user.id }
    can :read,   Tour, tour_claim: { approval_steps: { approver_id: user.id } }
    can :read,   TourClaim, finance_approver_id: user.id
    can :review, TourClaim do |c| c.current_reviewer?(user) end

    can :read, [ TravelMode, City, Project, BudgetLineItem, BudgetLineItemCode ]

    # --- bank details: own accounts; the claim's Finance person sees the account chosen on it
    can [ :read, :create, :update, :toggle, :make_primary ], BankAccount, user_id: user.id
    can :read, BankAccount do |b|
      b.tour_claims.where(finance_approver_id: user.id).exists? ||
        (user.pd_finance? && b.tour_claims.where(finance_approver_id: nil).exists?)   # no Finance set → PD Finance handles it
    end

    # --- PD HR: cutoff day rules, travel mode master, employees -----------
    if user.pd_hr?
      can :manage, ClaimCutoffRule
      can :manage, TravelMode
      can :manage, [ City, Location ]
      can [ :read, :create, :update, :import, :export ], User
      can :read, [ Tour, TourClaim ]
    end

    # --- PD Finance: per-km rates, finance masters, final approval --------
    if user.pd_finance?
      can [ :read, :create ], MileageRate
      can :manage, TravelMode
      can :manage, [ Project, BudgetLineItem, BudgetLineItemCode ]
      can :read, [ Tour, TourClaim ]
    end
  end
end

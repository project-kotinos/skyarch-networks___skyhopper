# record is a Infrastructure.
class NodePolicy < ApplicationPolicy
  def show?
    user.allow?(record)
  end


  %i[run_bootstrap? edit? update? cook? apply_dish? update_attributes? edit_attributes? yum_update?].each do |action|
    define_method(action) do
      user.admin? and user.allow?(record)
    end
  end

  def recipes?;true end
end